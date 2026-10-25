"""Shared SQL check expressions for visit date precision."""


def precision_check(column: str, precision_column: str) -> str:
    """Validate date/precision consistency and canonical storage."""

    return f"""
        (
            ({column} IS NULL AND {precision_column} IS NULL)
            OR
            (
                {column} IS NOT NULL
                AND {precision_column} IS NOT NULL
                AND {precision_column} IN ('day', 'month', 'year')
                AND (
                    {precision_column} = 'day'
                    OR (
                        {precision_column} = 'month'
                        AND strftime('%d', {column}) = '01'
                    )
                    OR (
                        {precision_column} = 'year'
                        AND strftime('%m-%d', {column}) = '01-01'
                    )
                )
            )
        )
    """


def range_check() -> str:
    """Validate whether a partial-date range can be chronologically valid."""

    return """
        ended_on IS NULL
        OR (
            started_on IS NOT NULL
            AND started_on <=
                CASE ended_on_precision
                    WHEN 'day' THEN ended_on
                    WHEN 'month'
                        THEN date(
                            ended_on,
                            'start of month',
                            '+1 month',
                            '-1 day'
                        )
                    WHEN 'year'
                        THEN date(
                            ended_on,
                            'start of year',
                            '+1 year',
                            '-1 day'
                        )
                END
        )
    """
