# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative 'fibonacci'

module MorphicHelix
  # Array-level statistics and permutations (Ruby reference for the CBQN kernels in cbqn/arrays/).
  module Arrays
    module_function

    # Distinct symbols in ascending order with their counts.
    def frequencies(seq)
      syms = seq.uniq.sort
      [syms, syms.map { |s| seq.count(s) }]
    end

    # Shannon entropy in bits: (sum of -p ln p, accumulated left to right) / ln 2. The summation order
    # and the use of natural log are fixed so that Ruby and CBQN produce bit-identical doubles.
    def entropy(seq)
      _, counts = frequencies(seq)
      n = seq.length.to_f
      counts.map { |c| p = c / n; -(p * Math.log(p)) }.reduce(0.0) { |acc, x| acc + x } / Math.log(2)
    end

    # Largest Fibonacci number <= n that is coprime to n (always exists: F = 1).
    def fib_stride(n)
      fs = [1, 1]
      fs << (fs[-1] + fs[-2]) while fs[-1] + fs[-2] <= n
      fs.select { |f| f.gcd(n) == 1 }.max
    end

    def fib_perm(n)
      f = fib_stride(n)
      (0...n).map { |i| (i * f) % n }
    end

    def fib_permute(xs) = fib_perm(xs.length).map { |j| xs[j] }

    def fib_unpermute(ys)
      p = fib_perm(ys.length)
      out = Array.new(ys.length)
      p.each_with_index { |j, i| out[j] = ys[i] }
      out
    end
  end
end
