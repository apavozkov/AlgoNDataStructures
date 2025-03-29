require 'rgeo'
require 'ruby2d'
require 'set'

##################################
### КОНФИГУРАЦИОННЫЕ ПАРАМЕТРЫ ###
##################################

MAP_WIDTH = 800
MAP_HEIGHT = 800

MAX_RECURSION_LEVEL = 6
START_POINT = [10, 10]
GOAL_POINT = [790, 790]

OBSTACLES_DATA = [
  [[0, 97], [0, 300], [372, 300], [243, 97]],
  [[600, 200], [600, 250], [700, 250], [700, 200]],
  [[0, 600], [0, 700], [300, 700], [300, 600]],
  [[500, 100], [500, 150], [600, 150], [600, 100]],
  [[405, 503], [195, 503], [195, 553], [405, 553]],
  [[10, 763], [800, 763], [800, 783], [15, 783]],
  [[400, 400], [800, 400], [800, 700], [300, 745]]
]

# Настройки отображения
BACKGROUND_COLOR = 'black'
CELL_BORDER_COLOR = 'gray'
OBSTACLE_COLOR = 'red'
PATH_COLOR = 'blue'
START_COLOR = 'green'
GOAL_COLOR = 'yellow'
PATH_WIDTH = 3
POINT_RADIUS = 8

# Настройки анимации
ANIMATION_SPEED = 0.1  

##############################
### ОСНОВНОЙ КОД ПРОГРАММЫ ###
##############################

factory = RGeo::Cartesian.factory

class Cell
  attr_reader :x, :y, :width, :height, :level, :children, :neighbors

  def initialize(x, y, width, height, level = 0)
    @x = x
    @y = y
    @width = width
    @height = height
    @level = level
    @children = []
    @neighbors = []
  end

  def center
    [x + width/2.0, y + height/2.0]
  end

  def corners
    [
      [x, y],
      [x + width, y],
      [x + width, y + height],
      [x, y + height]
    ]
  end

  def fully_inside_obstacle?(obstacles, factory)
    corners.all? do |cx, cy|
      point = factory.point(cx, cy)
      obstacles.any? { |obstacle| obstacle.contains?(point) }
    end
  end

  def intersects_obstacle?(obstacles, factory)
    return false if fully_inside_obstacle?(obstacles, factory)
    
    points_to_check = [
      factory.point(x, y),
      factory.point(x + width, y),
      factory.point(x + width, y + height),
      factory.point(x, y + height),
      factory.point(x + width/2, y + height/2)
    ]

    points_to_check.each do |point|
      obstacles.each do |obstacle|
        return true if obstacle.contains?(point)
      end
    end

    sides = [
      [[x, y], [x + width, y]],
      [[x + width, y], [x + width, y + height]],
      [[x + width, y + height], [x, y + height]],
      [[x, y + height], [x, y]]
    ]

    obstacles.each do |obstacle|
      obstacle_points = obstacle.exterior_ring.points.map { |p| [p.x, p.y] }
      
      sides.each do |side_start, side_end|
        (0...obstacle_points.size).each do |i|
          obst_start = obstacle_points[i]
          obst_end = obstacle_points[(i + 1) % obstacle_points.size]
          
          if segments_intersect?(
            side_start[0], side_start[1], side_end[0], side_end[1],
            obst_start[0], obst_start[1], obst_end[0], obst_end[1]
          )
            return true
          end
        end
      end
    end

    false
  end

  def segments_intersect?(x1, y1, x2, y2, x3, y3, x4, y4)
    denominator = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
    return false if denominator == 0

    ua = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)).to_f / denominator
    ub = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)).to_f / denominator

    ua.between?(0, 1) && ub.between?(0, 1)
  end

  def split(obstacles, factory, max_level = MAX_RECURSION_LEVEL)
    return if @level >= max_level
    return if fully_inside_obstacle?(obstacles, factory)
    
    if intersects_obstacle?(obstacles, factory)
      half_width = width / 2.0
      half_height = height / 2.0

      @children = [
        Cell.new(x, y, half_width, half_height, level + 1),
        Cell.new(x + half_width, y, half_width, half_height, level + 1),
        Cell.new(x, y + half_height, half_width, half_height, level + 1),
        Cell.new(x + half_width, y + half_height, half_width, half_height, level + 1)
      ]

      @children.each { |child| child.split(obstacles, factory, max_level) }
    end
  end

  def all_cells
    if @children.empty?
      [self]
    else
      @children.flat_map(&:all_cells)
    end
  end

  def add_neighbor(other)
    @neighbors << other unless @neighbors.include?(other)
  end

  def touches?(other)
    (x <= other.x + other.width && x + width >= other.x) &&
    (y <= other.y + other.height && y + height >= other.y)
  end
end

def obstacle_between?(cell1, cell2, obstacles, factory)
  steps = 5
  (1..steps-1).each do |i|
    t = i.to_f / steps
    x = cell1.center[0] * (1 - t) + cell2.center[0] * t
    y = cell1.center[1] * (1 - t) + cell2.center[1] * t
    
    point = factory.point(x, y)
    obstacles.each do |obstacle|
      return true if obstacle.contains?(point)
    end
  end
  
  false
end

def build_neighbor_graph(cells, obstacles, factory)
  cells.each_with_index do |cell1, i|
    cells[i+1..-1].each do |cell2|
      if cell1.touches?(cell2) && !obstacle_between?(cell1, cell2, obstacles, factory)
        cell1.add_neighbor(cell2)
        cell2.add_neighbor(cell1)
      end
    end
  end
end

def a_star(start_cell, goal_cell)
  open_set = Set.new([start_cell])
  came_from = {}
  g_score = Hash.new(Float::INFINITY)
  g_score[start_cell] = 0
  f_score = Hash.new(Float::INFINITY)
  f_score[start_cell] = heuristic(start_cell, goal_cell)

  until open_set.empty?
    current = open_set.min_by { |cell| f_score[cell] }
    
    if current == goal_cell
      return reconstruct_path(came_from, current)
    end

    open_set.delete(current)
    
    current.neighbors.each do |neighbor|
      tentative_g_score = g_score[current] + distance(current, neighbor)
      
      if tentative_g_score < g_score[neighbor]
        came_from[neighbor] = current
        g_score[neighbor] = tentative_g_score
        f_score[neighbor] = g_score[neighbor] + heuristic(neighbor, goal_cell)
        open_set.add(neighbor) unless open_set.include?(neighbor)
      end
    end
  end

  nil
end

def heuristic(cell1, cell2)
  dx = (cell1.center[0] - cell2.center[0]).abs
  dy = (cell1.center[1] - cell2.center[1]).abs
  Math.sqrt(dx*dx + dy*dy)
end

def distance(cell1, cell2)
  heuristic(cell1, cell2)
end

def reconstruct_path(came_from, current)
  total_path = [current]
  while came_from.key?(current)
    current = came_from[current]
    total_path << current
  end
  total_path.reverse
end

obstacles = OBSTACLES_DATA.map { |points| 
  points.map! { |x,y| [x.to_f, y.to_f] }
  factory.polygon(factory.linear_ring(points.map { |x, y| factory.point(x, y) })) 
}

root = Cell.new(0, 0, MAP_WIDTH, MAP_HEIGHT)
root.split(obstacles, factory)

cells = root.all_cells.reject { |cell| cell.fully_inside_obstacle?(obstacles, factory) }

build_neighbor_graph(cells, obstacles, factory)

start_cell = cells.find { |cell| 
  cell.x <= START_POINT[0] && START_POINT[0] < cell.x + cell.width &&
  cell.y <= START_POINT[1] && START_POINT[1] < cell.y + cell.height
}

goal_cell = cells.find { |cell| 
  cell.x <= GOAL_POINT[0] && GOAL_POINT[0] < cell.x + cell.width &&
  cell.y <= GOAL_POINT[1] && GOAL_POINT[1] < cell.y + cell.height
}

path = a_star(start_cell, goal_cell)

set title: "Pathfinding - #{cells.size} cells", 
    width: MAP_WIDTH, 
    height: MAP_HEIGHT, 
    background: BACKGROUND_COLOR

cells.each do |cell|
  Rectangle.new(
    x: cell.x, y: cell.y,
    width: cell.width, height: cell.height,
    color: 'black',
    z: 1
  )
  
  Line.new(
    x1: cell.x, y1: cell.y,
    x2: cell.x + cell.width, y2: cell.y,
    width: 1,
    color: CELL_BORDER_COLOR,
    z: 1
  )
  Line.new(
    x1: cell.x + cell.width, y1: cell.y,
    x2: cell.x + cell.width, y2: cell.y + cell.height,
    width: 1,
    color: CELL_BORDER_COLOR,
    z: 1
  )
  Line.new(
    x1: cell.x + cell.width, y1: cell.y + cell.height,
    x2: cell.x, y2: cell.y + cell.height,
    width: 1,
    color: CELL_BORDER_COLOR,
    z: 1
  )
  Line.new(
    x1: cell.x, y1: cell.y + cell.height,
    x2: cell.x, y2: cell.y,
    width: 1,
    color: CELL_BORDER_COLOR,
    z: 1
  )
end

obstacles.each do |obstacle|
  points = obstacle.exterior_ring.points.map { |p| [p.x, p.y] }
  
  (1..points.size-2).each do |i|
    Triangle.new(
      x1: points[0][0], y1: points[0][1],
      x2: points[i][0], y2: points[i][1],
      x3: points[i+1][0], y3: points[i+1][1],
      color: OBSTACLE_COLOR,
      z: 2
    )
  end
end

Circle.new(
  x: START_POINT[0], y: START_POINT[1],
  radius: POINT_RADIUS, color: START_COLOR, sectors: 32,
  z: 4
)
Circle.new(
  x: GOAL_POINT[0], y: GOAL_POINT[1],
  radius: POINT_RADIUS, color: GOAL_COLOR, sectors: 32,
  z: 4
)

if path
  path_segments = []
  current_index = 0
  last_time = Time.now

  update do
    if path && current_index < path.size - 1
      if Time.now - last_time >= ANIMATION_SPEED
        cell1 = path[current_index]
        cell2 = path[current_index + 1]
        
        segment = Line.new(
          x1: cell1.center[0], y1: cell1.center[1],
          x2: cell2.center[0], y2: cell2.center[1],
          width: PATH_WIDTH,
          color: PATH_COLOR,
          z: 3
        )
        path_segments << segment
        current_index += 1
        last_time = Time.now
      end
    end
  end
end

show