---
name: alliance-docs
description: >-
  Query the Alliance (DRAC) HPC docs RAG API so agents can look up how the
  cluster, software stack, and site guides work before acting. Use broadly for
  Alliance-specific HPC workflows, tools, software, Slurm, storage, accounts,
  cloud, cluster behaviour, and local documentation that may be newer than the
  model's training data.
---

# Alliance Docs RAG API

Use this skill as an agentic documentation lookup layer for Alliance (DRAC) HPC
work. It is meant for AI agents such as Claude Code, Cursor CLI, and other coding
or operations agents that need to inspect current Alliance documentation before
making changes, writing commands, generating job scripts, installing software, or
advising on cluster workflows.

The API provides semantic search over the Alliance HPC documentation wiki. Query
it when you need to know how something works on Alliance systems instead of
relying on memory or generic Linux/HPC assumptions. The docs are updated
regularly and cover all Alliance clusters.

## When to query

Query this skill before acting on Alliance-specific assumptions, especially for:

- Software and tools: modules, applications, Python, R, MATLAB, containers, and
  package setup
- Slurm and scheduling: job scripts, GPU flags, partitions, arrays, MPI jobs,
  accounts, QOS, and cluster-specific submission behaviour
- File transfer: Globus, data transfer nodes, rsync, SCP/SFTP, and transfer
  guidance
- Accounts and access: CCDB, RAC/RAS allocations, passwords, MFA, SSH, and
  access procedures
- Cloud and services: OpenStack, VMs, flavors, volumes, networking, security
  groups, and floating IPs
- Any Alliance guide, procedure, or workflow where guessing could produce the
  wrong command, wrong resource request, or stale advice

This skill is broad by design. If the task touches Alliance HPC infrastructure,
software, docs, or cluster operations and the answer may depend on current local
documentation, query the API first.

## POST /query

```bash
curl -s -X POST https://docs-api.vulcan.alliancecan.ca/query \
  -H 'Content-Type: application/json' \
  -d '{"question": "your question here", "top_n": 5}'
```

| Field | Required | Default | Notes |
|---|---:|---:|---|
| `question` | yes | — | Plain English or French |
| `top_n` | no | `8` | Chunks to return, from 1 to 30 |

Response chunks include `content`, `source`, and `similarity` from 0 to 1.
Scores above about `0.68` are usually useful. Use `top_n: 3–5` for focused
questions and `top_n: 8–10` for broad topics.

## How to use the results

Read the returned chunks, extract the relevant operational guidance, and apply it
to the task. Do not paste raw wiki markup unless the user specifically asks for
raw output.

If the returned chunks are weak or incomplete, retry with a more specific query,
alternate terminology, or the relevant cluster, tool, application, command, or
service name. If the docs still do not provide a clear answer, state that the API
did not return enough information and proceed conservatively rather than
inventing details.

## Agent rules

- Query before making Alliance-specific assumptions.
- Prefer current docs over training data for local cluster behaviour.
- Prefer high-similarity chunks and cross-check broad, operational, or
  policy-related topics.
- Do not invent cluster names, node specs, GPU types, module versions, quotas,
  policies, command flags, or account procedures.
- When another Alliance skill handles the hands-on workflow, use this skill to
  confirm current docs and then apply the specialized skill.

## Related skills

Use `alliance-software` for hands-on CVMFS, Lmod, `module spider`, software
loading, and Python virtual environment setup.

Use `alliance-slurm` for Slurm job submission, job scripts, GPU/GRES discovery,
queue monitoring, scheduling, and troubleshooting.
