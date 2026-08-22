# Context Handoff — {{PROJECT}}

> Use this template when an agent crosses the 70% context threshold (FACTORY.md §5.2).
> Fill, save as `handoffs/handoff_<stage>_<n>.md`, then respawn the agent with this file.

## Stage
- Current stage: S__ (Ingest | Golden | Module | Integ | UVM | Release)
- Context % at handoff: ___

## Work done so far
- 

## In-progress
- 

## Next goals
1. 
2. 

## Key decisions locked
- 

## Open questions
- 

## Relevant files / snippets
```
```

## Verified invariants (do not regress)
- Constants from `rtl/{{MODULE}}_pkg.sv`, checked vs golden.
- Golden model cleared §5.1 gate before any RTL checked against it.
