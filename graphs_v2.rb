require 'set'
require 'ruby2d'
require 'rgeo'

class Grid
  attr_reader :width, :height, :cell_size, :obstacles, :subcells

  def initialize(width, height, cell_size, obstacles)
    @width = width
    @height = height
    @cell_size = cell_size
    @factory = RGeo::Cartesian.simple_factory
    @obstacles = obstacles.map { |poly| @factory.polygon(@factory.linear_ring(poly.map { |p| @factory.point(*p) })) }
    @grid = Array.new((height / cell_size).ceil) { Array.new((width / cell_size).ceil, true) }
    @subcells = {} 
    mark_obstacles
    split_boundary_cells
  end

  def split_boundary_cells
    @grid.each_with_index do |row, y|
      row.each_with_index do |cell, x|
        next unless cell
        corners = [
          [x * @cell_size, y * @cell_size],
          [(x+1) * @cell_size, y * @cell_size],
          [(x+1) * @cell_size, (y+1) * @cell_size],
          [x * @cell_size, (y+1) * @cell_size]
        ]
        if corners.any? { |cx, cy| @obstacles.any? { |poly| poly.contains?(@factory.point(cx, cy)) } }
          @subcells[[x, y]] = Array.new(4, false) 
          4.times do |i|
            sub_x = x + (i % 2) * 0.5
            sub_y = y + (i / 2) * 0.5
            sub_center = [(sub_x + 0.25) * @cell_size, (sub_y + 0.25) * @cell_size]
            @subcells[[x, y]][i] = @obstacles.none? { |poly| poly.contains?(@factory.point(*sub_center)) }
          end
        end
      end
    end
  end


  def mark_obstacles
    @obstacles.each do |polygon|
      envelope = polygon.envelope
      points = envelope.exterior_ring.points
      min_x = points.map(&:x).min
      max_x = points.map(&:x).max
      min_y = points.map(&:y).min
      max_y = points.map(&:y).max
  
      (min_y..max_y).step(@cell_size) do |y|
        (min_x..max_x).step(@cell_size) do |x|
          point = @factory.point(x, y)
          if polygon.contains?(point)
            cell_x = (x / @cell_size).floor
            cell_y = (y / @cell_size).floor
            @grid[cell_y][cell_x] = false if cell_y < @grid.size && cell_x < @grid[0].size
          end
        end
      end
    end
  end

  def neighbors(cell)
    x, y = cell
    neighbors = []
    if x.is_a?(Float) || y.is_a?(Float)
      base_x = x.floor
      base_y = y.floor
      subcell_index = ((x - base_x) * 2).round + ((y - base_y) * 2).round * 2
      directions = [
        [0.5, 0], [-0.5, 0], [0, 0.5], [0, -0.5],
        [0.5, 0.5], [0.5, -0.5], [-0.5, 0.5], [-0.5, -0.5] 
      ]
      
      directions.each do |dx, dy|
        nx, ny = x + dx, y + dy
        
        if (nx - nx.floor).abs < 0.001 && (ny - ny.floor).abs < 0.001
          nx = nx.round
          ny = ny.round
          next unless nx >= 0 && ny >= 0 && nx < @grid[0].size && ny < @grid.size
          next unless @grid[ny][nx]
        else
          base_nx = nx.floor
          base_ny = ny.floor
          next unless @subcells.key?([base_nx, base_ny])
          
          subcell_idx = ((nx - base_nx) * 2).round + ((ny - base_ny) * 2).round * 2
          next unless @subcells[[base_nx, base_ny]][subcell_idx]
        end
        
        neighbors << [nx, ny]
      end
    else
      directions = [
        [1, 0], [-1, 0], [0, 1], [0, -1],
        [1, 1], [1, -1], [-1, 1], [-1, -1]
      ]
      
      directions.each do |dx, dy|
        nx, ny = x + dx, y + dy
        
        if nx >= 0 && ny >= 0 && nx < @grid[0].size && ny < @grid.size
          if @subcells.key?([nx, ny])
            4.times do |i|
              if @subcells[[nx, ny]][i]
                sub_x = nx + (i % 2) * 0.5
                sub_y = ny + (i / 2) * 0.5
                neighbors << [sub_x, sub_y]
              end
            end
          else
            neighbors << [nx, ny] if @grid[ny][nx]
          end
        end
      end
    end
    
    neighbors
  end
  def heuristic(a, b)
    ax = a.is_a?(Float) ? a : a[0] + 0.5
    ay = a.is_a?(Float) ? a : a[1] + 0.5
    bx = b.is_a?(Float) ? b : b[0] + 0.5
    by = b.is_a?(Float) ? b : b[1] + 0.5
    
    Math.sqrt((ax - bx)**2 + (ay - by)**2)
  end

  def a_star(start, goal)
    open_set = Set.new([start])
    came_from = {}
    g_score = Hash.new(Float::INFINITY)
    g_score[start] = 0
    f_score = Hash.new(Float::INFINITY)
    f_score[start] = heuristic(start, goal)

    until open_set.empty?
      current = open_set.min_by { |cell| f_score[cell] }
      return reconstruct_path(came_from, current) if current == goal

      open_set.delete(current)
      neighbors(current).each do |neighbor|
        tentative_g_score = g_score[current] + heuristic(current, neighbor)
        if tentative_g_score < g_score[neighbor]
          came_from[neighbor] = current
          g_score[neighbor] = tentative_g_score
          f_score[neighbor] = g_score[neighbor] + heuristic(neighbor, goal)
          open_set.add(neighbor)
        end
      end
    end

    return []
  end

  def reconstruct_path(came_from, current)
    total_path = [current]
    while came_from.key?(current)
      current = came_from[current]
      total_path << current
    end
    total_path.reverse
  end
end

class Visualization
  def initialize(grid, path)
    @grid = grid
    @path = path
    @path_index = 0
    @path_squares = []
    setup_window
    draw_grid
    draw_obstacles
    draw_start_and_goal
    start_animation
  end

  def setup_window
    Window.set(
      width: @grid.width,
      height: @grid.height,
      title: "Pathfinding Visualization",
      background: 'black'
    )
  end

  def draw_grid
    (0...@grid.width).step(@grid.cell_size) do |x|
      Line.new(x1: x, y1: 0, x2: x, y2: @grid.height, width: 1, color: 'gray')
    end
    (0...@grid.height).step(@grid.cell_size) do |y|
      Line.new(x1: 0, y1: y, x2: @grid.width, y2: y, width: 1, color: 'gray')
    end

    @grid.subcells.each_key do |x, y|
      Line.new(
        x1: (x + 0.5) * @grid.cell_size, y1: y * @grid.cell_size,
        x2: (x + 0.5) * @grid.cell_size, y2: (y + 1) * @grid.cell_size,
        width: 1, color: 'gray'
      )
      Line.new(
        x1: x * @grid.cell_size, y1: (y + 0.5) * @grid.cell_size,
        x2: (x + 1) * @grid.cell_size, y2: (y + 0.5) * @grid.cell_size,
        width: 1, color: 'gray'
      )
    end
  end

def draw_obstacles
  @grid.obstacles.each do |polygon|
    points = polygon.exterior_ring.points
    points.each_cons(2) do |p1, p2|
      Line.new(
        x1: p1.x, y1: p1.y,
        x2: p2.x, y2: p2.y,
        width: 2,
        color: 'red'
      )
    end
  end
  @grid.subcells.each do |(x, y), subcells|
    subcells.each_with_index do |allowed, i|
      next if allowed

      sub_x = x + (i % 2) * 0.5
      sub_y = y + (i / 2) * 0.5
      Square.new(
        x: sub_x * @grid.cell_size,
        y: sub_y * @grid.cell_size,
        size: @grid.cell_size / 2,
        color: [1, 0, 0, 0.3] 
      )
    end
  end
end

  def draw_start_and_goal
    start = @path.first
    goal = @path.last
    Square.new(
      x: start[0] * @grid.cell_size,
      y: start[1] * @grid.cell_size,
      size: @grid.cell_size,
      color: 'lime'
    )
    Square.new(
      x: goal[0] * @grid.cell_size,
      y: goal[1] * @grid.cell_size,
      size: @grid.cell_size,
      color: 'yellow'
    )
  end

  def start_animation
    @animation = true
    Window.update do
      update_animation
    end
  end

  def update_animation
    return unless @animation && @path_index < @path.size

    current = @path[@path_index]
    if current[0].is_a?(Float) || current[1].is_a?(Float)
      x, y = current
      base_x = x.floor
      base_y = y.floor
      sub_x = ((x - base_x) * 2).round
      sub_y = ((y - base_y) * 2).round
      
      size = @grid.cell_size / 2
      render_x = base_x * @grid.cell_size + sub_x * size
      render_y = base_y * @grid.cell_size + sub_y * size
    else
      x, y = current
      size = @grid.cell_size
      render_x = x * @grid.cell_size
      render_y = y * @grid.cell_size
    end

    square = Square.new(
      x: render_x,
      y: render_y,
      size: size,
      color: 'blue',
      z: 10
    )
    @path_squares << square

    @path_index += 1
    sleep(0.05)
    Window.update { update_animation }
  end

  def show
    Window.show
  end
end

# Пример использования
width = 800
height = 800
cell_size = 10
obstacles = [
  [[0, 97], [0, 300], [372, 300], [243, 97]], 
  [[600, 200], [600, 250], [700, 250], [700, 200]], 
  [[0, 600], [0, 700], [300, 700], [300, 600]], 
  [[500, 100], [500, 150], [600, 150], [600, 100]], 
  [[405, 503], [195, 503], [195, 553], [405, 553]], 
  [[400, 400], [800, 400], [800, 700], [300, 785]]  
]
start = [1, 1]
goal = [78, 71] 

grid = Grid.new(width, height, cell_size, obstacles)
path = grid.a_star(start, goal)

app = Visualization.new(grid, path)
app.show