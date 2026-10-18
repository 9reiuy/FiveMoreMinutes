# 3D Random Dream parity audit

Work in progress. PASS requires an executed check; unverified behavior is PARTIAL.

Scope: reuse formal 2D gameplay, retain camera and BSP, repair rendering and door interactions.

Initial findings:
- Door material crops an already-unwrapped leaf mesh a second time.
- Door root is at the hinge instead of the door-edge center.
- The open leaf loses its 2D collision and has no 3D collision shape.
- Existing route tests disable door collision, so do not validate physical traversal.
- Room opacity and unified aim highlighting are absent.
- Depth clones duplicate scripted branches and omit parent transforms.

Executed checks and remaining limitations will be recorded here.
