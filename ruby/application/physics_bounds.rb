# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

module MorphicHelix
  # Optional analytical bounds (closed-form formulas only, no simulation). Constants: CODATA 2018 exact /
  # recommended SI values. Every result is an idealised theoretical bound under the stated assumptions;
  # none of it is a claim about what this program or any real machine achieves.
  module PhysicsBounds
    K_B = 1.380649e-23        # J/K (exact)
    HBAR = 1.054571817e-34    # J s
    H = 6.62607015e-34        # J s (exact)
    C = 299_792_458.0         # m/s (exact)
    G = 6.67430e-11           # m^3 kg^-1 s^-2
    LN2 = Math.log(2)

    module_function

    # Landauer: minimum energy to erase one bit at temperature T (assumes quasi-static erasure).
    def landauer_joules_per_bit(temperature_k) = K_B * temperature_k * LN2

    # Finite memory budget: bits that can be erased with energy E at temperature T (Landauer-limited).
    def landauer_bit_budget(energy_j, temperature_k) = energy_j / landauer_joules_per_bit(temperature_k)

    # Bekenstein bound on information (bits) in radius R with energy E: I <= 2 pi R E / (hbar c ln 2).
    def bekenstein_bits(radius_m, energy_j) = 2 * Math::PI * radius_m * energy_j / (HBAR * C * LN2)

    # Margolus-Levitin: max orthogonal state transitions per second for mean energy E: 2E / (pi hbar).
    def margolus_levitin_ops_per_s(energy_j) = 2 * energy_j / (Math::PI * HBAR)

    # Bremermann's limit: m c^2 / h bits per second for mass m (speculative interpretation; labelled).
    def bremermann_bits_per_s(mass_kg) = mass_kg * C * C / H

    # Schwarzschild radius r_s = 2 G M / c^2.
    def schwarzschild_radius(mass_kg) = 2 * G * mass_kg / (C * C)

    # Bekenstein-Hawking entropy S = k_B c^3 A / (4 G hbar), A = 4 pi r_s^2. Returns [S in J/K, S in bits].
    def black_hole_entropy(mass_kg)
      area = 4 * Math::PI * schwarzschild_radius(mass_kg)**2
      s = K_B * C**3 * area / (4 * G * HBAR)
      [s, s / (K_B * LN2)]
    end

    ASSUMPTIONS = [
      'Formulas are idealised upper bounds; real hardware is many orders of magnitude below them.',
      'Black-hole entropy and gravitational computation bounds are speculative as models of computation.',
      'Nothing here simulates the observable universe; a finite local machine cannot do that.'
    ].freeze
  end
end
