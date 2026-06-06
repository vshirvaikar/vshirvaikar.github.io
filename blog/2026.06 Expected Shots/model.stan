data {
  int<lower=0> N_phases;
  vector<lower=0.01>[N_phases] phase_duration;
  array[N_phases] int<lower=0> shot_counts; 
  array[N_phases] int p_team; 
  array[N_phases] int p_opp; 
  array[N_phases] int p_margin;

  int<lower=0> N_shots;
  vector<lower=0>[N_shots] shot_xg;
  array[N_shots] int s_team;  
  array[N_shots] int s_margin;
  
  int n_teams;
}

parameters {
  real<lower=0, upper=5> i_lambda;       // shot quantity log-rate
  real<lower=-8, upper=0> i_mu;          // shot quality mean (lognormal)
  real<lower=0.01, upper=5> i_sigma;     // shot quality SD (lognormal)
  real<lower=0.01, upper=100> phi;       // NB2 dispersion

  vector[n_teams] att_talent_raw;
  vector[n_teams] def_talent_raw;
  real<lower=0> s_qual;       // scale between attacking quantity and quality

  vector[4] m_vol_raw;        // non-tied game-state effects on quantity
  vector[4] m_qual_raw;       // non-tied game-state effects on quality
}

transformed parameters {
  vector[n_teams] att_talent;
  vector[n_teams] def_talent;
  vector[5] m_vol;
  vector[5] m_qual;

  // Sum-to-zero identification: team effects are relative to league average.
  att_talent = att_talent_raw - mean(att_talent_raw);
  def_talent = def_talent_raw - mean(def_talent_raw);

  // Tie state (index 3) is the fixed baseline.
  m_vol[1] = m_vol_raw[1];
  m_vol[2] = m_vol_raw[2];
  m_vol[3] = 0;
  m_vol[4] = m_vol_raw[3];
  m_vol[5] = m_vol_raw[4];

  m_qual[1] = m_qual_raw[1];
  m_qual[2] = m_qual_raw[2];
  m_qual[3] = 0;
  m_qual[4] = m_qual_raw[3];
  m_qual[5] = m_qual_raw[4];
}

model {
  // Priors -- relatively uninformative
  i_lambda ~ normal(2.5, 0.5); 
  i_mu ~ normal(-2.5, 0.5);
  i_sigma ~ normal(1, 0.2); 
  phi ~ exponential(1);

  att_talent_raw ~ normal(0, 0.2); 
  def_talent_raw ~ normal(0, 0.2);
  s_qual ~ normal(1, 0.2);

  m_vol_raw ~ normal(0, 0.5); 
  m_qual_raw ~ normal(0, 0.5);

  // QUANTITY LIKELIHOOD (Phase Counts)
  // Logic: Calculate log-mean directly to prevent exp() overflow
  for (n in 1:N_phases) {
    real log_l = i_lambda + att_talent[p_team[n]] - def_talent[p_opp[n]] + m_vol[p_margin[n]];
    real log_expected_n = log_l + log(phase_duration[n] / 90.0);
    shot_counts[n] ~ neg_binomial_2_log(log_expected_n, phi);
  }

  // QUALITY LIKELIHOOD (Individual Shot Intensity)
  // Logic: Each shot value is a draw from a global Log-Normal distribution
  for (s in 1:N_shots) {
    real mu = i_mu + (att_talent[s_team[s]] * s_qual) + m_qual[s_margin[s]];
    shot_xg[s] ~ lognormal(mu, i_sigma);
  }
}

generated quantities {
  // Transformation to Multipliers (Relative to Tied = 1.0)
  vector[5] vol_mult = exp(m_vol - m_vol[3]);
  vector[5] qual_mult = exp(m_qual - m_qual[3]);
  
  // Real-world avg shot quality (Expected Value of the Log-Normal)
  real league_avg_q = exp(i_mu + 0.5 * i_sigma^2);
}