import hashlib
import random
def stream(seed, *names):
    text = "/".join(str(n) for n in (seed,) + names)
    digest = hashlib.blake2b(text.encode(), digest_size=8).digest()
    return random.Random(int.from_bytes(digest, "big"))
class Streams:
    def __init__(self, seed, candidate=0, reseed=None, force=None):
        self.seed = seed
        self.candidate = candidate
        self.reseed = dict(reseed or {})
        self.force = dict(force or {})
        self.used = []
    def __call__(self, module_id):
        gen = self.reseed.get(module_id, 0)
        self.used.append(module_id)
        return stream(self.seed, self.candidate, module_id, gen)
