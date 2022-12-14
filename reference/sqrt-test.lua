
-- do
--   local units = {
--       ['seconds'] = 1,
--       ['milliseconds'] = 1000,
--       ['microseconds'] = 1000000,
--       ['nanoseconds'] = 1000000000
--   }

--   function benchmark(unit, decPlaces, n, f, ...)
--       local elapsed = 0
--       local multiplier = units[unit]
--       for i = 1, n do
--           local now = os.clock()
--           f(...)
--           elapsed = elapsed + (os.clock() - now)
--       end
--       print(string.format('%d function calls | %.'.. decPlaces ..'f %s elapsed', n, elapsed * multiplier, unit, (elapsed / n) * multiplier))
--   end
-- end

-- local function fast_inv_sqrt(number)
--   local i, x2, y, threehalfs = 0, 0, 0, 1.5

--   x2 = number * 0.5
--   y = number
--   i = string.unpack("I4", string.pack("f", y))
--   i = 0x5f3759df - (i >> 1)
--   y = string.unpack("f", string.pack("I4", i))
--   y = y * (threehalfs - (x2 * y * y))

--   return y
-- end

-- local time = os.clock()

-- local large_number = 179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368

-- print('fast_inv_sqrt')
-- benchmark('milliseconds', 3, 1000000, fast_inv_sqrt, large_number)
-- print('math.sqrt')
-- benchmark('milliseconds', 3, 1000000, math.sqrt, large_number)
-- print('^')
-- benchmark('milliseconds', 3, 1000000, function() local _ =  large_number end)
  -- print(fast_inv_sqrt(179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368))
-- print(1 / math.sqrt(179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368))

-- print(string.format("time: %.4f", os.clock() - time))

-- print(number_to_bytes(66309))

