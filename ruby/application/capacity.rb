# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

module MorphicHelix
  # Computational capacity model. All quantities here are either (a) theoretical inputs chosen by the
  # caller, or (b) measurements passed in from a benchmark run. Nothing is measured inside this module.
  module Capacity
    DEFAULT_P = 100e12 # FLOP/s, theoretical target (assumption, not a measurement)

    module_function

    # Port of modelWorkload from fibonacci_braid.js (identical arithmetic and fields).
    def model_workload(target_tflops: 100, seconds: 1, flops_per_step: 1000)
      raise ArgumentError, 'invalid workload parameters' unless target_tflops.positive? && seconds >= 0 && flops_per_step.positive?

      operations = target_tflops * 1e12 * seconds
      { hypotheticalTargetTFLOPS: target_tflops, seconds: seconds, operations: operations,
        hypotheticalSteps: (operations / flops_per_step).floor,
        note: 'A budget projection only. Turing-machine steps and bitwise XOR are NOT floating-point operations.' }
    end

    # O = P * t (theoretical operation budget)
    def budget(p: DEFAULT_P, t:) = p * t

    # Moore's-law transistor-count scenario T(t) = T0 * 2^(t / tau). A historical scenario for transistor
    # counts only; it says nothing about delivered computational performance and is not a law of nature.
    def moore_transistors(t0:, years:, tau_years: 2.0)
      t0 * (2.0**(years / tau_years))
    end
  end
end
