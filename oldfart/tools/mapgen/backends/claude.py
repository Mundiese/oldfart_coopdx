import importlib.util
import json
from . import Unavailable, BadReply, api_key, scrub, schema as schemamod
FALLBACK_BETA = "server-side-fallback-2026-07-01"
MAX_TOKENS = 16000
TOOL_ROUNDS = 4
def sdk_installed():
    if importlib.util.find_spec("anthropic") is not None:
        return True
    from . import sdkenv
    return sdkenv.activate() and importlib.util.find_spec("anthropic") is not None
def _client(key, timeout):
    import anthropic
    return anthropic.Anthropic(api_key=key, timeout=timeout, max_retries=1)
def _uses_fallback(model):
    return not model.startswith("claude-haiku")
def _errors():
    try:
        import anthropic
    except ImportError:
        return ()
    return ((anthropic.AuthenticationError, "the key was refused - check it in Preferences"),
            (anthropic.PermissionDeniedError, "the key may not use this model"),
            (anthropic.NotFoundError, "the model was not found"),
            (anthropic.RateLimitError, "rate limited - try again in a minute"),
            (anthropic.BadRequestError, "the request was refused"),
            (anthropic.APITimeoutError, "no answer in time"),
            (anthropic.APIConnectionError, "no connection (offline?)"),
            (anthropic.APIStatusError, "the API answered with an error"))
def _detail(why, key=None):
    try:
        import anthropic
        if not isinstance(why, anthropic.BadRequestError):
            return ""
    except ImportError:
        return ""
    msg = getattr(why, "message", None) or str(why)
    body = getattr(why, "body", None)
    if isinstance(body, dict):
        err = body.get("error")
        if isinstance(err, dict) and err.get("message"):
            msg = err["message"]
    msg = " ".join(scrub(msg, key).split())
    return " (400: %s)" % (msg[:160] + ("..." if len(msg) > 160 else "")) if msg else ""
class Session:
    def __init__(self, config, client=None, prompts=None, tools=None):
        self.prompts = dict({"system": schemamod.system_prompt, "schema": schemamod.schema,
                             "user": schemamod.user_prompt}, **(prompts or {}))
        self.config = config
        self.tools = tools
        self.model = config.claude_model
        self.usage = {}
        self.messages = []
        if client is None:
            if not sdk_installed():
                raise Unavailable("the anthropic package is not installed - %s" % sdk_how())
            key, _ = api_key(config.key_file)
            if not key:
                raise Unavailable("no API key - set ANTHROPIC_API_KEY or add it in Preferences")
            try:
                client = _client(key, config.timeout)
            except Exception as why:
                raise Unavailable(scrub(why, key))
            self._key = key
        else:
            self._key = None
        self.client = client
    def _request(self):
        req = dict(
            model=self.model,
            max_tokens=MAX_TOKENS,
            system=[{"type": "text", "text": self.prompts["system"](),
                     "cache_control": {"type": "ephemeral"}}],
            messages=self.messages,
            output_config={"format": {"type": "json_schema",
                                      "schema": self.prompts["schema"]()}},
        )
        if self.tools is not None:
            req["tools"] = self.tools.definitions()
        if _uses_fallback(self.model):
            req.update(betas=[FALLBACK_BETA], fallbacks="default")
        return req
    def _send(self, req):
        if _uses_fallback(self.model):
            return self.client.beta.messages.create(**req)
        return self.client.messages.create(**req)
    def _call(self):
        try:
            resp = self._send(self._request())
        except Exception as why:
            for cls, words in _errors():
                if isinstance(why, cls):
                    raise Unavailable(words + _detail(why, self._key))
            if isinstance(why, (OSError, TimeoutError)):
                raise Unavailable("no connection (offline?)")
            raise Unavailable(scrub("%s: %s" % (why.__class__.__name__, why), self._key))
        u = getattr(resp, "usage", None)
        if u is not None:
            for k in ("input_tokens", "output_tokens", "cache_read_input_tokens",
                      "cache_creation_input_tokens"):
                self.usage[k] = self.usage.get(k, 0) + (getattr(u, k, 0) or 0)
        self.model = getattr(resp, "model", None) or self.model
        stop = getattr(resp, "stop_reason", None)
        if stop == "refusal":
            det = getattr(resp, "stop_details", None)
            raise Unavailable("the model declined the wish%s" % (
                " (%s)" % det.category if det is not None and getattr(det, "category", None)
                else ""))
        content = list(getattr(resp, "content", None) or [])
        self.messages.append({"role": "assistant", "content": content})
        return stop, content
    def ask(self, text, offline_raw=None, base=None, problems=None):
        if problems and self.messages:
            self.messages.append({"role": "user",
                                  "content": self.prompts["user"](text, problems=problems)})
        else:
            self.messages = [{"role": "user",
                              "content": self.prompts["user"](text, offline_raw, base)}]
        stop, content = self._call()
        rounds = 0
        while stop == "tool_use" and self.tools is not None and rounds < TOOL_ROUNDS:
            rounds += 1
            results = []
            for b in content:
                if getattr(b, "type", None) != "tool_use":
                    continue
                try:
                    out = self.tools.run(b.name, dict(getattr(b, "input", None) or {}))
                    results.append({"type": "tool_result", "tool_use_id": b.id,
                                    "content": out})
                except Asked:
                    raise
                except Exception as why:
                    results.append({"type": "tool_result", "tool_use_id": b.id,
                                    "content": "error: %s" % why, "is_error": True})
            self.messages.append({"role": "user", "content": results})
            stop, content = self._call()
        if stop == "max_tokens":
            raise BadReply("the answer was cut off")
        text_out = "".join(getattr(b, "text", "") for b in content
                           if getattr(b, "type", None) == "text")
        try:
            return json.loads(text_out)
        except ValueError:
            raise BadReply("not JSON")
class Asked(Exception):
    def __init__(self, question):
        Exception.__init__(self, question.get("ask", ""))
        self.question = question
def sdk_how():
    from . import sdkenv
    return ("in the Studio: Preferences > Wish backends > Install Claude support; by hand "
            "from the checkout: %s (the oldfart-studio package already carries it)"
            % sdkenv.manual_command())
def status(config, probe=False, client=None):
    from . import Status
    if client is None and not sdk_installed():
        return Status("claude", False, "Claude: not installed",
                      "the anthropic package is missing - %s; until then the offline "
                      "parser is used" % sdk_how())
    key, where = api_key(config.key_file)
    if client is None and not key:
        return Status("claude", False, "Claude: no key",
                      "set ANTHROPIC_API_KEY or add the key in Preferences > Wish backends; "
                      "the offline parser is used")
    if not probe:
        return Status("claude", True, "Claude",
                      "%s, key from %s - not tested yet (Test asks the API)"
                      % (config.claude_model, where or "the test client"))
    try:
        c = client or _client(key, min(config.timeout, 15.0))
        c.models.retrieve(config.claude_model)
    except Exception as why:
        words = next((w for cls, w in _errors() if isinstance(why, cls)), None)
        return Status("claude", False, "Claude: unreachable",
                      words or scrub(why, key))
    return Status("claude", True, "Claude: reachable", "%s answers" % config.claude_model)
