ALTER TABLE submission_reviews
    ADD COLUMN rejection_severity VARCHAR(20);

ALTER TABLE submission_reviews
    ADD CONSTRAINT chk_submission_reviews_rejection_severity
        CHECK (rejection_severity IS NULL OR rejection_severity IN ('MISTAKE', 'BAD', 'FRAUD'));
