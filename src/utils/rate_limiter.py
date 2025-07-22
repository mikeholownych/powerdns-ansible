import time
from threading import Lock


class TokenBucket:
    def __init__(self, max_tokens: int, refill_period: int) -> None:
        self.max_tokens = max_tokens
        self.tokens = max_tokens
        self.refill_period = refill_period
        self.last_refill = time.time()
        self.lock = Lock()

    def consume(self, tokens: int = 1) -> bool:
        with self.lock:
            now = time.time()
            elapsed = now - self.last_refill
            if elapsed > self.refill_period:
                self.tokens = self.max_tokens
                self.last_refill = now
            if self.tokens >= tokens:
                self.tokens -= tokens
                return True
            return False
