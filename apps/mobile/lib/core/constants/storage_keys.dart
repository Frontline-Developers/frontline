// Shared storage key used by ReportingDatasource (write) and
// MyReportsDatasource (read/delete). Both must reference this constant to
// prevent silent key divergence.
const kReportTokensStorageKey = 'frontline_report_tokens';

// PIN lock screen keys.
const kPinHashStorageKey = 'frontline_pin_hash';
const kPinSaltStorageKey = 'frontline_pin_salt';
const kAppSetupCompleteKey = 'frontline_setup_complete';
const kBiometricEnabledKey = 'frontline_biometric_enabled';
