use std::ops::Range;

use chrono::NaiveDate;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PurgedFold {
    pub train: Range<usize>,
    pub validation: Range<usize>,
    pub test: Range<usize>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PurgedDayFold {
    pub train_days: Vec<NaiveDate>,
    pub validation_days: Vec<NaiveDate>,
    pub test_days: Vec<NaiveDate>,
    pub purged_days: Vec<NaiveDate>,
    pub embargoed_days: Vec<NaiveDate>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PurgedCalibrationFold {
    pub train_days: Vec<NaiveDate>,
    pub validation_days: Vec<NaiveDate>,
    pub calibration_days: Vec<NaiveDate>,
    pub test_days: Vec<NaiveDate>,
    pub purged_days: Vec<NaiveDate>,
    pub embargoed_days: Vec<NaiveDate>,
}

pub fn expanding_calibration_folds(
    session_dates: &[NaiveDate],
    initial_train_days: usize,
    validation_days: usize,
    calibration_days: usize,
    test_days: usize,
    purge_days: usize,
    embargo_days: usize,
) -> Vec<PurgedCalibrationFold> {
    let mut days = session_dates.to_vec();
    days.sort_unstable();
    days.dedup();
    let mut folds = Vec::new();
    let mut train_end = initial_train_days;
    while train_end + purge_days + validation_days + calibration_days + embargo_days + test_days
        <= days.len()
    {
        let purge_end = train_end + purge_days;
        let validation_end = purge_end + validation_days;
        let calibration_end = validation_end + calibration_days;
        let embargo_end = calibration_end + embargo_days;
        let test_end = embargo_end + test_days;
        folds.push(PurgedCalibrationFold {
            train_days: days[..train_end].to_vec(),
            purged_days: days[train_end..purge_end].to_vec(),
            validation_days: days[purge_end..validation_end].to_vec(),
            calibration_days: days[validation_end..calibration_end].to_vec(),
            embargoed_days: days[calibration_end..embargo_end].to_vec(),
            test_days: days[embargo_end..test_end].to_vec(),
        });
        train_end += test_days;
    }
    folds
}

/// Expanding walk-forward folds whose atomic unit is a complete session.
///
/// `session_dates` may contain one entry per minute; it is sorted and
/// de-duplicated internally. Purge and embargo sessions are deliberately not
/// returned in any model partition, which prevents adjacent minutes from the
/// same day (and labels crossing a boundary) leaking across folds.
pub fn expanding_day_folds(
    session_dates: &[NaiveDate],
    initial_train_days: usize,
    validation_days: usize,
    test_days: usize,
    purge_days: usize,
    embargo_days: usize,
) -> Vec<PurgedDayFold> {
    let mut days = session_dates.to_vec();
    days.sort_unstable();
    days.dedup();
    let mut folds = Vec::new();
    let mut train_end = initial_train_days;
    while train_end + purge_days + validation_days + embargo_days + test_days <= days.len() {
        let purge_end = train_end + purge_days;
        let validation_end = purge_end + validation_days;
        let embargo_end = validation_end + embargo_days;
        let test_end = embargo_end + test_days;
        folds.push(PurgedDayFold {
            train_days: days[..train_end].to_vec(),
            purged_days: days[train_end..purge_end].to_vec(),
            validation_days: days[purge_end..validation_end].to_vec(),
            embargoed_days: days[validation_end..embargo_end].to_vec(),
            test_days: days[embargo_end..test_end].to_vec(),
        });
        train_end += test_days;
    }
    folds
}

pub fn expanding_folds(
    rows: usize,
    initial_train: usize,
    validation: usize,
    test: usize,
    purge: usize,
    embargo: usize,
) -> Vec<PurgedFold> {
    let mut output = Vec::new();
    let mut train_end = initial_train;
    while train_end + purge + validation + embargo + test <= rows {
        let validation_start = train_end + purge;
        let validation_end = validation_start + validation;
        let test_start = validation_end + embargo;
        let test_end = test_start + test;
        output.push(PurgedFold {
            train: 0..train_end,
            validation: validation_start..validation_end,
            test: test_start..test_end,
        });
        train_end += test;
    }
    output
}

#[cfg(test)]
mod day_tests {
    use chrono::NaiveDate;

    use super::expanding_day_folds;

    #[test]
    fn folds_keep_whole_days_disjoint_and_ordered() {
        let dates = (1..=20)
            .flat_map(|day| {
                let date = NaiveDate::from_ymd_opt(2026, 7, day).unwrap();
                [date, date, date]
            })
            .collect::<Vec<_>>();
        let folds = expanding_day_folds(&dates, 8, 3, 2, 1, 1);
        assert!(!folds.is_empty());
        for fold in folds {
            assert!(fold.train_days.last() < fold.purged_days.first());
            assert!(fold.purged_days.last() < fold.validation_days.first());
            assert!(fold.validation_days.last() < fold.embargoed_days.first());
            assert!(fold.embargoed_days.last() < fold.test_days.first());
            assert_eq!(fold.purged_days.len(), 1);
            assert_eq!(fold.embargoed_days.len(), 1);
        }
    }
}
