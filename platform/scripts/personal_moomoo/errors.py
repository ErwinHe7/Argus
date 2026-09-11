class PersonalError(Exception):
    """An allow-listed error safe to show in the browser."""

    def __init__(self, code: str, message: str, status: int = 400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status


def unavailable() -> PersonalError:
    return PersonalError(
        "broker_unavailable",
        "moomoo could not complete this request. Check OpenD and your broker account, then refresh.",
        503,
    )
