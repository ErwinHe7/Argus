export type IntradayRun = {
  run_id: string;
  profile: 'licensed' | 'real_data' | string;
  status: 'queued' | 'running' | 'completed' | 'failed';
  source_mode: string;
  evidence_tier: string;
  created_at: string;
  completed_at?: string | null;
  report_path?: string | null;
  option_status?: string | null;
  error_message?: string | null;
  data_coverage?: {
    rows?: number;
    start?: string | null;
    end?: string | null;
    sessions?: number;
    sources?: Record<string, number>;
  };
  artifact_manifest?: Record<string, { path: string; bytes: number }>;
};

export type IntradayMetrics = {
  total_return?: number;
  annualized_return?: number | null;
  sharpe?: number | null;
  sortino?: number | null;
  maximum_drawdown?: number;
  calmar?: number | null;
  win_rate?: number;
  average_win?: number;
  average_loss?: number;
  profit_factor?: number;
  expectancy_per_trade?: number;
  median_return_per_trade?: number;
  number_of_trades?: number;
  trades_per_day?: number;
  percentage_no_trade_days?: number;
  average_holding_period?: number;
  average_mfe?: number;
  average_mae?: number;
  mfe_capture_ratio?: number;
  observed_sessions?: number;
  annualization_status?: string;
};

export type IntradayTrade = {
  trade_id?: string;
  trade_date?: string;
  setup?: string;
  direction?: number;
  signal_time?: string;
  entry_time?: string;
  exit_time?: string;
  underlying_entry?: number;
  underlying_exit?: number;
  gross_pnl?: number;
  cost?: number;
  net_pnl?: number;
  gross_return?: number;
  net_return?: number;
  mfe?: number;
  mae?: number;
  holding_minutes?: number;
  exit_reason?: string;
  model_probability?: number;
  score?: number;
  fold?: number;
};

export type AnalogCase = {
  target_date?: string;
  rank?: number;
  analog_date?: string;
  distance?: number;
  similarity?: number;
  forward_return?: number;
  mfe?: number;
  mae?: number;
  target_actual_return?: number;
  ret_5m?: number;
  ret_15m?: number;
  volume_zscore?: number;
  buy_pressure_proxy?: number;
  breadth_score?: number;
  closing_short_cover_score?: number;
};

export type CandidateDecision = {
  candidate_id?: string;
  timestamp?: string;
  session_date?: string;
  setup_type?: string;
  direction?: number;
  decision?: 'selected' | 'rejected';
  score?: number;
  expected_return?: number;
  expected_net_return?: number;
  win_probability?: number;
  predicted_mfe?: number;
  predicted_mae?: number;
  uncertainty?: number;
  rejection_reason?: string;
  reason_codes?: string;
};

export type ModelDiagnostic = {
  fold?: number;
  model?: string;
  train_rows?: number;
  validation_rows?: number;
  test_rows?: number;
  validation_brier?: number | null;
};

export type AuditRow = {
  audit_type: string;
  row_number: number;
  payload: Record<string, unknown>;
};

export type TimeBucketEffect = {
  bucket_5m: number;
  clock_label_et: string;
  observed_bar_direction: 'up' | 'down';
  train_samples: number;
  validation_samples: number;
  test_samples: number;
  train_reversal_rate: number;
  validation_reversal_rate: number;
  test_reversal_rate: number;
  validation_strong_reversal_rate: number;
  test_strong_reversal_rate: number;
  validation_mean_reversal_return: number;
  test_mean_reversal_return: number;
  validation_p_value: number;
  validation_q_value: number;
  selected_on_validation: boolean;
};

export type IntradayOverview = {
  status?: 'empty';
  message?: string;
  run?: IntradayRun;
  metrics?: IntradayMetrics;
  equity?: Array<{ date: string; equity: number; drawdown: number }>;
  trades?: IntradayTrade[];
  candidates?: CandidateDecision[];
  analogs?: AnalogCase[];
  diagnostics?: ModelDiagnostic[];
  audits?: AuditRow[] | { time_bucket_reversals?: TimeBucketEffect[] };
  current_hint?: {
    as_of: string;
    target: string;
    bucket_5m: number;
    clock_label: string;
    suggested_direction: number;
    abstain: boolean;
    prediction: {
      expected_return: number;
      win_probability: number;
      similarity_score: number;
      uncertainty: number;
      analogs: AnalogCase[];
    };
    horizons: Array<{
      horizon_minutes: number;
      as_of: string;
      bucket_5m: number;
      suggested_direction: number;
      abstain: boolean;
      prediction: {
        expected_return: number;
        win_probability: number;
        similarity_score: number;
        uncertainty: number;
        analogs: AnalogCase[];
      };
    }>;
  } | null;
  model_specification?: Record<string, unknown>;
};
