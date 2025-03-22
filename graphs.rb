require 'set'
require 'ruby2d'

class Grid
  attr_reader :width, :height, :cell_size, :obstacles

  def initialize(width, height, cell_size, obstacles)
    @width = width
    @height = height
    @cell_size = cell_size
    @obstacles = obstacles
    @grid = Array.new((height / cell_size).ceil) { Array.new((width / cell_size).ceil, true) }
    mark_obstacles
  end

  def mark_obstacles
    @obstacles.each do |polygon|
      min_x = polygon.map { |p| p[0] }.min
      max_x = polygon.map { |p| p[0] }.max
      min_y = polygon.map { |p| p[1] }.min
      max_y = polygon.map { |p| p[1] }.max

      (min_y..max_y).step(@cell_size) do |y|
        (min_x..max_x).step(@cell_size) do |x|
          if point_in_polygon?(x, y, polygon)
            cell_x = (x / @cell_size).floor
            cell_y = (y / @cell_size).floor
            @grid[cell_y][cell_x] = false if cell_y < @grid.size && cell_x < @grid[0].size
          end
        end
      end
    end
  end

  def point_in_polygon?(x, y, polygon)
    inside = false
    n = polygon.size
    j = n - 1
    (0...n).each do |i|
      xi, yi = polygon[i]
      xj, yj = polygon[j]
      intersect = ((yi > y) != (yj > y)) &&
                 (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
      inside = !inside if intersect
      j = i
    end
    inside
  end

  def neighbors(cell)
    x, y = cell
    neighbors = []
    [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
      nx, ny = x + dx, y + dy
      if nx >= 0 && ny >= 0 && nx < @grid[0].size && ny < @grid.size && @grid[ny][nx]
        neighbors << [nx, ny]
      end
    end
    neighbors
  end

  def heuristic(a, b)
    Math.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2)
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
      Line.new(
        x1: x, y1: 0,
        x2: x, y2: @grid.height,
        width: 1,
        color: 'black'
      )
    end
    (0...@grid.height).step(@grid.cell_size) do |y|
      Line.new(
        x1: 0, y1: y,
        x2: @grid.width, y2: y,
        width: 1,
        color: 'black'
      )
    end
  end

  def draw_obstacles
    @grid.obstacles.each do |polygon|
      min_x = polygon.map { |p| p[0] }.min
      max_x = polygon.map { |p| p[0] }.max
      min_y = polygon.map { |p| p[1] }.min
      max_y = polygon.map { |p| p[1] }.max

      (min_y..max_y).step(@grid.cell_size) do |y|
        (min_x..max_x).step(@grid.cell_size) do |x|
          if point_in_polygon?(x, y, polygon)
            Square.new(
              x: x,
              y: y,
              size: @grid.cell_size,
              color: 'red'
            )
          end
        end
      end
    end
  end

  def point_in_polygon?(x, y, polygon)
    inside = false
    n = polygon.size
    j = n - 1
    (0...n).each do |i|
      xi, yi = polygon[i]
      xj, yj = polygon[j]
      intersect = ((yi > y) != (yj > y)) &&
                 (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
      inside = !inside if intersect
      j = i
    end
    inside
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
    return unless @animation

    if @path_index < @path.size
      x, y = @path[@path_index]
      Square.new(
        x: x * @grid.cell_size,
        y: y * @grid.cell_size,
        size: @grid.cell_size,
        color: 'blue',
        z: 10
      )
      @path_index += 1
      sleep(0.05)
      Window.update do
        update_animation
      end
    else
      @animation = false
    end
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
  [[0, 100], [0, 300], [300, 300], [300, 100]], 
  [[600, 200], [600, 250], [700, 250], [700, 200]], 
  [[200, 600], [200, 700], [300, 700], [300, 600]], 
  [[500, 100], [500, 150], [600, 150], [600, 100]], 
  [[400, 500], [200, 500], [200, 550], [400, 550]], 
  [[400, 400], [800, 400], [800, 600], [400, 600]]  
]
start = [1, 1]
goal = [78, 69] 

grid = Grid.new(width, height, cell_size, obstacles)
path = grid.a_star(start, goal)

app = Visualization.new(grid, path)
app.show