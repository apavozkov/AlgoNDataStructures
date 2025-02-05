# Функция для чтения параметров существ и ресурсов (значения могут быть заданы вручную)
def read_data
  # Параметры мага (стоимость в золоте, драгоценностях, кристаллах)
  m1, m2, m3 = 12, 3, 3
  # Параметры рыцаря
  k1, k2, k3 = 7, 2, 1
  # Параметры дракона
  d1, d2, d3 = 20, 5, 10
  # Запасы ресурсов (золото, драгоценности, кристаллы)
  r1, r2, r3 = 100, 50, 30
  # Сила существ
  p1, p2, p3 = 5, 3, 10

  {
    m: { gold: m1, jewels: m2, crystals: m3, power: p1 },
    k: { gold: k1, jewels: k2, crystals: k3, power: p2 },
    d: { gold: d1, jewels: d2, crystals: d3, power: p3 },
    resources: { gold: r1, jewels: r2, crystals: r3 }
  }
end

data = read_data

max_strength = 0
best_combination = { m: 0, k: 0, d: 0 }

# Максимальное количество драконов
d_max = []
d_max << data[:resources][:gold] / data[:d][:gold] if data[:d][:gold] > 0
d_max << data[:resources][:jewels] / data[:d][:jewels] if data[:d][:jewels] > 0
d_max << data[:resources][:crystals] / data[:d][:crystals] if data[:d][:crystals] > 0
d_max = d_max.min || 0

(0..d_max).each do |d|
  # Проверка ресурсов для драконов
  used_gold_d = d * data[:d][:gold]
  used_jewels_d = d * data[:d][:jewels]
  used_crystals_d = d * data[:d][:crystals]

  next if used_gold_d > data[:resources][:gold] ||
          used_jewels_d > data[:resources][:jewels] ||
          used_crystals_d > data[:resources][:crystals]

  rem_gold = data[:resources][:gold] - used_gold_d
  rem_jewels = data[:resources][:jewels] - used_jewels_d
  rem_crystals = data[:resources][:crystals] - used_crystals_d

  # Вычисление максимального количества рыцарей
  k_candidates = []
  k_candidates << rem_gold / data[:k][:gold] if data[:k][:gold] > 0
  k_candidates << rem_jewels / data[:k][:jewels] if data[:k][:jewels] > 0
  k_candidates << rem_crystals / data[:k][:crystals] if data[:k][:crystals] > 0

  if k_candidates.empty?
    # Если рыцари не требуют ресурсов, проверяем остатки
    next unless rem_gold >= 0 && rem_jewels >= 0 && rem_crystals >= 0
    k_max = Float::INFINITY # В реальности обрабатывается отдельно, но здесь упрощено
  else
    k_max = k_candidates.min
    k_max = 0 if k_max < 0
  end

  (0..k_max).each do |k|
    # Проверка ресурсов для рыцарей
    used_gold_k = k * data[:k][:gold]
    used_jewels_k = k * data[:k][:jewels]
    used_crystals_k = k * data[:k][:crystals]

    next if used_gold_k > rem_gold ||
            used_jewels_k > rem_jewels ||
            used_crystals_k > rem_crystals

    rem_gold_k = rem_gold - used_gold_k
    rem_jewels_k = rem_jewels - used_jewels_k
    rem_crystals_k = rem_crystals - used_crystals_k

    # Вычисление максимального количества магов
    m_candidates = []
    m_candidates << rem_gold_k / data[:m][:gold] if data[:m][:gold] > 0
    m_candidates << rem_jewels_k / data[:m][:jewels] if data[:m][:jewels] > 0
    m_candidates << rem_crystals_k / data[:m][:crystals] if data[:m][:crystals] > 0

    if m_candidates.empty?
      # Если маги не требуют ресурсов
      next unless rem_gold_k >= 0 && rem_jewels_k >= 0 && rem_crystals_k >= 0
      m = Float::INFINITY # Упрощенный случай (не обрабатывается)
    else
      m = m_candidates.min
      m = 0 if m < 0
    end

    # Расчет общей силы
    total = d * data[:d][:power] + k * data[:k][:power] + m * data[:m][:power]

    if total > max_strength
      max_strength = total
      best_combination = { m: m, k: k, d: d }
    end
  end
end

puts "Максимальная сила: #{max_strength}"
puts "Лучшая комбинация:"
puts "Маги: #{best_combination[:m]}, Рыцари: #{best_combination[:k]}, Драконы: #{best_combination[:d]}"
