# Параметры на вход
k1 = [2, 20, 2, 5, 10]
k2 = [1, 8, 15, 15, 7]
m  = [2, 20, 6, 2]

# Решение жадным методом
def greedy_production_time(k1, k2, m)
  n = k1.size
  return 0 if n == 0

  current_line = k1[0] < k2[0] ? :line1 : :line2
  total_time = [k1[0], k2[0]].min

  (1...n).each do |j|
    transition = j-1 < m.size ? m[j-1] : 0

    stay_time = total_time + (current_line == :line1 ? k1[j] : k2[j])
    switch_time = total_time + transition + (current_line == :line1 ? k2[j] : k1[j])

    if stay_time <= switch_time
      total_time = stay_time
    else
      total_time = switch_time
      current_line = current_line == :line1 ? :line2 : :line1
    end
  end

  total_time
end

# Решение через динамическое программирование
def dp_production_time(k1, k2, m)
  n = k1.size
  return 0 if n == 0

  dp1 = Array.new(n, 0)
  dp2 = Array.new(n, 0)

  dp1[0] = k1[0]
  dp2[0] = k2[0]

  (1...n).each do |j|
    transition = j-1 < m.size ? m[j-1] : 0

    dp1[j] = [dp1[j-1] + k1[j], dp2[j-1] + transition + k1[j]].min
    dp2[j] = [dp2[j-1] + k2[j], dp1[j-1] + transition + k2[j]].min
  end

  [dp1.last, dp2.last].min
end

greedy_time = greedy_production_time(k1, k2, m)
dp_time = dp_production_time(k1, k2, m)

puts "Жадный метод: #{greedy_time}"
puts "Щедрый метод: #{dp_time}"
