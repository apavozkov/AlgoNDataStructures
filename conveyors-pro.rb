# Блок для изменения входных данных
K = 9
D = 1497
k = [
  [2, 3, 4, 2, 7, 4],
  [1, 2, 3, 5, 1, 8],
  [3, 2, 1, 3, 6, 2],
  [2, 7, 2, 2, 5, 1],
  [7, 3, 4, 7, 1, 4],
  [5, 6, 2, 3, 5, 7],
  [3, 7, 2, 3, 3, 8],
  [4, 9, 2, 4, 4, 6],
  [6, 3, 2, 1, 7, 5]
]
m = [1, 2, 4, 5, 9] # Время переключения

# Проверка корректности входных данных
raise "Количество конвейеров K должно быть больше 0" unless K > 0
raise "Количество деталей D должно быть больше 0" unless D > 0
raise "Количество этапов на всех конвейерах должно быть одинаковым" unless k.all? { |arr| arr.size == k[0].size }
n = k[0].size # Количество этапов (определяется по первому конвейеру)
raise "Количество элементов в m должно быть равно n-1" unless m.size == n - 1

# Динамическое программирование с оптимизацией
prev = k.map { |conveyor| conveyor[0] }.freeze # Начальный этап

(1...n).each do |j|
  current = Array.new(K)
  # Находим глобальный минимум и второй минимум для предыдущего этапа
  min_prev = prev.min
  min_index = prev.index(min_prev)
  second_min_prev = prev.each_with_index.min_by { |val, i| i == min_index ? Float::INFINITY : val }[0]

  (0...K).each do |i|
    stay = prev[i] + k[i][j]
    switch_min = (prev[i] == min_prev ? second_min_prev : min_prev)
    switch = switch_min + k[i][j] + m[j-1]
    current[i] = [stay, switch].min
  end
  prev = current
end

t = prev # Минимальное время для одной детали на каждом конвейере

# Оптимальное распределение деталей
sum_inv = t.sum { |ti| 1.0 / ti }
details = Array.new(K, 0)

# Базовое распределение по пропорции
total_assigned = 0
t.each_with_index do |ti, i|
  details[i] = ((D * (1.0 / ti)) / sum_inv).floor
  total_assigned += details[i]
end

remaining = D - total_assigned

# Распределение оставшихся деталей к конвейерам с минимальным (d_i +1)*t_i
remaining.times do
  min_increment = Float::INFINITY
  best = 0
  t.each_with_index do |ti, i|
    increment = (details[i] + 1) * ti
    if increment < min_increment
      min_increment = increment
      best = i
    end
  end
  details[best] += 1
end

total_min_time = details.each_with_index.map { |d, i| d * t[i] }.max

puts "Минимальное время производства для #{D} деталей: #{total_min_time}"
