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
  # Извлечение параметров юнитов из конфига
  # Затраты ресурсов для мага
  m1 = UNIT_CONFIG[:mag][:gold];     m2 = UNIT_CONFIG[:mag][:gems];     m3 = UNIT_CONFIG[:mag][:crystals]
  # Затраты ресурсов для рыцаря
  k1 = UNIT_CONFIG[:knight][:gold];  k2 = UNIT_CONFIG[:knight][:gems];  k3 = UNIT_CONFIG[:knight][:crystals]
  # Затраты ресурсов для дракона
  d1 = UNIT_CONFIG[:dragon][:gold];  d2 = UNIT_CONFIG[:dragon][:gems];  d3 = UNIT_CONFIG[:dragon][:crystals]
  # Боевая сила юнитов
  p1 = UNIT_CONFIG[:mag][:power];    p2 = UNIT_CONFIG[:knight][:power]; p3 = UNIT_CONFIG[:dragon][:power]

  # Получение доступных ресурсов
  r1 = resources[:gold]
  r2 = resources[:gems]
  r3 = resources[:crystals]

  # Инициализация переменных для поиска максимума
  max_strength = 0
  best_army = {mag: 0, knight: 0, dragon: 0}

  # Расчет максимального возможного числа драконов
  # Для каждого ресурса вычисляем максимальное количество драконов, которое можно купить
  d_max = [d1 > 0 ? r1/d1 : 0, d2 > 0 ? r2/d2 : 0, d3 > 0 ? r3/d3 : 0].min

  # Основной цикл перебора количества драконов
  (0..d_max).each do |d|
    # Вычисляем остатки ресурсов после покупки d драконов
    g = r1 - d*d1  # Остаток золота
    gm = r2 - d*d2 # Остаток самоцветов
    c = r3 - d*d3  # Остаток кристаллов
    
    # Пропускаем итерацию если не хватает ресурсов
    next if g < 0 || gm < 0 || c < 0

    # Генерация кандидатов для распределения ресурсов
    candidates = []
    
    # Решаем системы уравнений для пар ресурсов
    [[m1, k1, g, m2, k2, gm],  # Золото и самоцветы
     [m1, k1, g, m3, k3, c],   # Золото и кристаллы
     [m2, k2, gm, m3, k3, c]].each do |a1, b1, c1, a2, b2, c2| # Самоцветы и кристаллы
      
      # Вычисляем определитель матрицы
      det = a1*b2 - a2*b1
      next if det == 0  # Пропускаем если система не имеет решения

      # Решение системы уравнений
      m = (c1*b2 - c2*b1).to_f / det
      k = (a1*c2 - a2*c1).to_f / det

      # Генерируем целочисленные кандидаты вокруг решения
      [m.floor, m.ceil].product([k.floor, k.ceil]).each do |m_cand, k_cand|
        candidates << [m_cand, k_cand] if m_cand >= 0 && k_cand >= 0
      end
    end

    # Добавление крайних случаев
    # Максимальное количество магов при нулевых рыцарях
    m_max = [m1 > 0 ? g/m1 : 0, m2 > 0 ? gm/m2 : 0, m3 > 0 ? c/m3 : 0].min
    candidates << [m_max.floor, 0]

    # Максимальное количество рыцарей при нулевых магах
    k_max = [k1 > 0 ? g/k1 : 0, k2 > 0 ? gm/k2 : 0, k3 > 0 ? c/k3 : 0].min
    candidates << [0, k_max.floor]

    # Нулевая армия
    candidates << [0, 0]

    # Проверка валидных кандидатов
    candidates.uniq.each do |m, k|
      next if m < 0 || k <0
      # Проверяем ограничения по всем ресурсам
      next if m*m1 + k*k1 > g
      next if m*m2 + k*k2 > gm
      next if m*m3 + k*k3 > c

      # Рассчитываем общую силу
      strength = p1*m + p2*k + p3*d
      
      # Обновляем максимум если нашли лучшее решение
      if strength > max_strength
        max_strength = strength
        best_army = {mag: m, knight: k, dragon: d}
      end
    end
  end

  # Возврат результата
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
