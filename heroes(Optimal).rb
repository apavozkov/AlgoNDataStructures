# Конфигурация параметров игры
UNIT_CONFIG = {
  mag:    {power: 6,  gold: 2,  gems: 0, crystals: 1},
  knight: {power: 10, gold: 1,  gems: 3, crystals: 0},
  dragon: {power: 30, gold: 5,  gems: 5, crystals: 5}
}.freeze

DRAGON_ART = <<~ART.freeze
                \\||/
                |  @___oo
      /\\  /\\   / (__,,,,|
     ) /^\\\\) ^\\/ _)
     )   /^\\/   _)
     )   _ /  / _)
 /\\  )/\\/ ||  | )_)
<  >      |(,,) )__)
 ||      /    \\)___)\\
 | \\____(      )___) )___
  \\______(_______;;; __;;;
ART

def format_number(n)
  n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def show_welcome
  header = "║ %-8s ║ %6s ║ %6s ║ %6s ║ %6s ║"
  divider = "╠══════════╬════════╬════════╬════════╬════════╣"
  
  puts "\n╔══════════╦════════╦════════╦════════╦════════╗"
  puts "║ Существо ║  Сила  ║ Золото ║ Драги. ║ Кр.    ║"
  puts divider

  UNIT_CONFIG.each do |unit, stats|
    name = case unit
           when :mag then "Маг"
           when :knight then "Рыцарь"
           when :dragon then "Дракон"
           end
    printf(header + "\n", name, 
           format_number(stats[:power]),
           format_number(stats[:gold]),
           format_number(stats[:gems]),
           format_number(stats[:crystals]))
  end
  puts "╚══════════╩════════╩════════╩════════╩════════╝"
  puts "\n#{DRAGON_ART}"
end

def get_resources
  puts "\n«Покажи свои гроши, смертный!»"
  resources = {}
  
  print "Золото: ".rjust(15)
  resources[:gold] = gets.chomp.to_i
  
  print "Драгоценности: ".rjust(15)
  resources[:gems] = gets.chomp.to_i
  
  print "Кристаллы: ".rjust(15)
  resources[:crystals] = gets.chomp.to_i
  
  resources
end

def calculate_optimal_army(resources)
  m1 = UNIT_CONFIG[:mag][:gold];     m2 = UNIT_CONFIG[:mag][:gems];     m3 = UNIT_CONFIG[:mag][:crystals]
  k1 = UNIT_CONFIG[:knight][:gold];  k2 = UNIT_CONFIG[:knight][:gems];  k3 = UNIT_CONFIG[:knight][:crystals]
  d1 = UNIT_CONFIG[:dragon][:gold];  d2 = UNIT_CONFIG[:dragon][:gems];  d3 = UNIT_CONFIG[:dragon][:crystals]
  p1 = UNIT_CONFIG[:mag][:power];    p2 = UNIT_CONFIG[:knight][:power]; p3 = UNIT_CONFIG[:dragon][:power]

  r1 = resources[:gold]
  r2 = resources[:gems]
  r3 = resources[:crystals]

  max_strength = 0
  best_army = {mag: 0, knight: 0, dragon: 0}

  d_max = [d1 > 0 ? r1/d1 : 0, d2 > 0 ? r2/d2 : 0, d3 > 0 ? r3/d3 : 0].min

  (0..d_max).each do |d|
    g = r1 - d*d1
    gm = r2 - d*d2
    c = r3 - d*d3
    next if g < 0 || gm < 0 || c < 0

    candidates = []

    [[m1, k1, g, m2, k2, gm],
     [m1, k1, g, m3, k3, c],
     [m2, k2, gm, m3, k3, c]].each do |a1, b1, c1, a2, b2, c2|
      
      det = a1*b2 - a2*b1
      next if det == 0

      m = (c1*b2 - c2*b1).to_f / det
      k = (a1*c2 - a2*c1).to_f / det

      [m.floor, m.ceil].product([k.floor, k.ceil]).each do |m_cand, k_cand|
        candidates << [m_cand, k_cand] if m_cand >= 0 && k_cand >= 0
      end
    end

    m_max = [m1 > 0 ? g/m1 : 0, m2 > 0 ? gm/m2 : 0, m3 > 0 ? c/m3 : 0].min
    candidates << [m_max.floor, 0]

    k_max = [k1 > 0 ? g/k1 : 0, k2 > 0 ? gm/k2 : 0, k3 > 0 ? c/k3 : 0].min
    candidates << [0, k_max.floor]

    candidates << [0, 0]

    candidates.uniq.each do |m, k|
      next if m < 0 || k <0
      next if m*m1 + k*k1 > g
      next if m*m2 + k*k2 > gm
      next if m*m3 + k*k3 > c

      strength = p1*m + p2*k + p3*d
      if strength > max_strength
        max_strength = strength
        best_army = {mag: m, knight: k, dragon: d}
      end
    end
  end

  {strength: max_strength, army: best_army}
end

def print_result_row(label, value)
  formatted_value = format_number(value).rjust(27)
  puts "║ #{label.ljust(10)} ║#{formatted_value} ║"
end

# Запуск программы
show_welcome
resources = get_resources
result = calculate_optimal_army(resources)

puts "\n╔═════════════════════════════════════════╗"
puts "║ Результаты оптимального набора армии:   ║"
puts "╠════════════╦════════════════════════════╣"
print_result_row("Драконы", result[:army][:dragon])
print_result_row("Рыцари", result[:army][:knight])
print_result_row("Маги", result[:army][:mag])
puts "╠════════════╩════════════════════════════╣"
puts "║ Суммарная сила: #{format_number(result[:strength]).rjust(23)} ║"
puts "╚═════════════════════════════════════════╝"
