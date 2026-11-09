"""Home-access broker for the Maria Padilha assistant.

The assistant never gets an unrestricted filesystem or shell.  This package is
the policy boundary described by ADR 0001: it only exposes user-approved roots,
reads text files by default, redacts secrets before content leaves the process,
and records metadata-only audit entries.
"""

from .broker import Broker
from .policy import Decision, Root

__all__ = ["Broker", "Decision", "Root"]
