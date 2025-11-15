# Remote Agent Orchestration

## Description

Expert knowledge for orchestrating remote AI agents to accomplish complex, multi-step infrastructure and deployment tasks. This skill teaches how to effectively command remote agents as "highly capable junior engineers," maximizing parallel execution while maintaining quality and minimizing deployment time.

Based on real-world deployments achieving 62% time reduction through optimized orchestration strategies.

## When to Use

Use this skill when you need to:
- Deploy complex multi-service applications on remote systems
- Orchestrate remote agents via MCP or similar protocols
- Coordinate multiple parallel tasks across distributed systems
- Plan and execute infrastructure deployments efficiently
- Manage remote agents performing system administration tasks
- Set up development environments on remote GPU servers
- Install and configure ML/AI model pipelines

## Core Principles

### 1. Treat Agents as Highly Capable Junior Engineers

**What This Means:**
- Will execute exactly what you ask, nothing more, nothing less
- Don't anticipate unstated requirements or question inefficient approaches
- Excellent at following complex multi-step procedures
- Strong technical capability but need clear, explicit direction
- Will "run far" with clear instructions but require active management

**Implications:**
- Be explicit about every step, don't assume interpretation
- Provide complete context upfront to avoid back-and-forth
- Verify critical checkpoints but trust their technical execution
- Give structured, actionable instructions rather than open-ended goals

### 2. Maximize Parallel Execution

**The Most Important Optimization:**

Parallel execution is the #1 factor in deployment speed. Identify all independent tasks upfront and run them simultaneously.

**Dependency Analysis Framework:**
```
Step 1: List all tasks required
Step 2: Identify dependencies between tasks
Step 3: Create dependency graph
Step 4: Identify all tasks with no dependencies (leaf nodes)
Step 5: Launch ALL leaf nodes in parallel
Step 6: As tasks complete, launch newly-unblocked tasks immediately
```

**Resource-Based Grouping:**
- **Network I/O**: All downloads (models, packages, repos) - run together
- **Disk I/O**: File operations, git operations - can overlap with network
- **CPU**: Compilation, builds - can run during I/O operations
- **GPU**: Service startups requiring GPU - sequence to avoid conflicts

**Example Parallel Batches:**
```bash
# BAD (Sequential - 25 minutes total)
1. Clone repo (30s)
2. Download model A (5 min)
3. Download model B (5 min)
4. Install packages (3 min)
5. Build frontend (8 min)
6. Start backend (2 min)
7. Start frontend (1 min)

# GOOD (Parallel - 10 minutes total)
Batch 1 (Parallel):
- Clone repo + Install packages (3 min)
- Download model A (5 min)
- Download model B (5 min)

Batch 2 (Parallel, after Batch 1):
- Build frontend (8 min)
- Start backend (2 min)

Batch 3 (After Batch 2):
- Start frontend (1 min)

Time saved: 60% reduction
```

### 3. Front-Load Information Gathering

**Before Starting ANY Work:**

```markdown
Phase 0: Pre-Planning (2-5 minutes)
1. Have agent read ALL relevant documentation
2. Agent presents complete requirements list
3. Ask user for ALL credentials/decisions at once
4. Agent builds dependency graph
5. Agent shows execution plan with time estimates
6. User approves → execution begins
```

**Questions to Ask Upfront:**
- What credentials are needed? (SSH keys, API tokens, passwords)
- Which directories/paths should be used?
- Are there any port preferences or conflicts to check?
- What configuration values need to be set?
- Which models/versions should be installed?

**Anti-Pattern (Avoid):**
```
Agent: "Starting task..."
[5 minutes later]
Agent: "I need credential X"
User: "Here it is"
[2 minutes later]
Agent: "I also need credential Y"
User: "Here it is"
[3 minutes later]
Agent: "One more thing, I need Z"

Time wasted: 10+ minutes
```

**Correct Pattern:**
```
You: "Before starting, read the docs and tell me 
     everything you'll need"
Agent: "I'll need: SSH key, Artifactory credentials,
        target directory, port preferences"
You: [Provides everything at once]
Agent: [Executes without interruption]

Time wasted: 0 minutes
```

## Orchestration Strategies

### Strategy 1: Fan-Out, Fan-In Pattern

**Structure:**
```
Single assessment/planning task
    ↓
Multiple parallel setup tasks
    ↓
Single integration test
```

**When to Use:**
- Independent setup steps with shared testing phase
- Resource provisioning followed by validation
- Model downloads followed by service startup

**Example:**
```
1. System Assessment (1 task)
   ↓
2. Parallel Setup (5 tasks):
   - Install packages
   - Download model A
   - Download model B
   - Configure SSH
   - Clone repository
   ↓
3. Integration Test (1 task)
```

**Benefit:** Maximum parallelization with clear verification points

### Strategy 2: Pipeline Stages

**Structure:**
```
Phase 1: All parallel tasks complete
    ↓
Phase 2: All parallel tasks complete
    ↓
Phase 3: All parallel tasks complete
```

**When to Use:**
- Clear dependency boundaries between phases
- Need to verify one phase before proceeding
- Resources from Phase N needed for Phase N+1

**Example:**
```
Phase 1 (Foundation):
├─ Install docker-compose
├─ Configure SSH
└─ Create directories

Phase 2 (Models):
├─ Download SAM models
├─ Download RT-DETR model
└─ Pull Ollama model

Phase 3 (Services):
├─ Start backend
└─ Start frontend
```

**Benefit:** Simple to reason about, easy to restart phases

### Strategy 3: Continuous Pipeline

**Structure:**
```
Chain A: Task 1 → Task 3 → Task 5
Chain B: Task 2 → Task 4 → Task 6
```

**When to Use:**
- Two or more independent chains of work
- Want maximum throughput with no idle time
- Resources don't conflict between chains

**Example:**
```
Backend Chain:
Install Python → Download ML models → Start API

Frontend Chain:
Install Node → Build app → Start container
```

**Benefit:** Zero idle time, maximum resource utilization

## Communication Patterns

### Effective Agent Instructions

**Template for High-Quality Instructions:**

```markdown
# Phase X: [Clear Phase Name]

## Context
[What we're trying to accomplish and why]

## Prerequisites
[What must be ready before starting]

## Tasks (Execute efficiently, parallelize where possible)

### 1. [Task Name]
Command: [Exact command or clear instruction]
Expected outcome: [What success looks like]
Verification: [How to check it worked]

### 2. [Task Name]
[Same structure]

## Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Report Back
Provide: [Specific information you need to know]
Format: [How to structure the response]
```

**Example:**

```markdown
# Phase 2: Model Downloads (PARALLEL TASKS)

## Context
We need SAM, RT-DETR, and Ollama models for the labeling service.
These are large downloads (6+ GB total) that can run simultaneously.

## Prerequisites
- Repository cloned
- Artifactory credentials in .env file
- Network connectivity verified

## Tasks (ALL PARALLEL - launch simultaneously)

### Task A: SAM Models
Command: 
cd ~/github/ATR/dataset_management/sam_assisted_labeling
source .env
./scripts/download_sam_models.sh

Expected outcome: 4 SAM model files (1.5 GB total)
Verification: ls -lh models/sam2.1_*.pt

### Task B: RT-DETR Model
Command:
cd ~/github/ATR/dataset_management/sam_assisted_labeling
source .env
./scripts/download_rtdetr_model.sh

Expected outcome: RT-DETR model files (120 MB)
Verification: ls -lh ~/ATR/pipelines/rtdetrv2/.../models/

### Task C: Ollama Model
Command:
ollama pull qwen2.5:7b

Expected outcome: qwen2.5:7b model (4.7 GB)
Verification: ollama list | grep qwen

## Success Criteria
- [ ] All 4 SAM models present
- [ ] RT-DETR model files verified
- [ ] Ollama model loaded and listed

## Report Back
Provide:
- Total download time for each task
- File sizes verified
- Any errors encountered
Format: Table showing task, duration, size, status
```

### Common Mistakes to Avoid

**❌ Vague Instructions:**
```
"Set up the models"
```

**✅ Specific Instructions:**
```
"Download 4 SAM 2.1 models using ./scripts/download_sam_models.sh,
then verify all 4 files exist in the models/ directory"
```

---

**❌ Sequential When Parallel Possible:**
```
"First download model A, then download model B, then download model C"
```

**✅ Explicit Parallelization:**
```
"Launch 3 parallel tasks:
Task 1: Download model A
Task 2: Download model B  
Task 3: Download model C
Report when ALL are complete"
```

---

**❌ Assuming Context:**
```
"Install Ollama"
```

**✅ Complete Context:**
```
"Install Ollama in userspace at ~/ollama using the official install script:
curl -fsSL https://ollama.com/install.sh | sh
Then verify with: ollama -v"
```

## Job Monitoring Best Practices

### Polling Strategy

**Match polling interval to expected duration:**

```python
polling_intervals = {
    'quick_commands': 2,      # ls, ps, health checks
    'service_start': 3,        # Service startup (10-30s)
    'package_install': 5,      # apt install, pip install
    'model_download': 10,      # Large file downloads
    'docker_build': 10,        # Container builds
    'long_running': 15,        # Very slow operations
}
```

**Monitoring Multiple Parallel Jobs:**

```bash
# Check all jobs in a single poll
for i in {1..100}; do
  job1=$(curl -s .../jobs/ID1 | jq -r '.status')
  job2=$(curl -s .../jobs/ID2 | jq -r '.status')
  job3=$(curl -s .../jobs/ID3 | jq -r '.status')
  
  echo "[$i] Job1: $job1 | Job2: $job2 | Job3: $job3"
  
  # Smart exit: when all complete
  if [ "$job1" = "completed" ] && 
     [ "$job2" = "completed" ] && 
     [ "$job3" = "completed" ]; then
    break
  fi
  
  sleep 5
done

# Retrieve all results
curl .../jobs/ID1 | jq -r '.result'
curl .../jobs/ID2 | jq -r '.result'
curl .../jobs/ID3 | jq -r '.result'
```

### Handling Failures

**Build Resilience into Instructions:**

```markdown
## Task: Install Package X

Commands:
1. Try installation: sudo apt install package-x
2. If fails (exit code != 0):
   - Check if already installed: which package-x
   - Try alternate source: snap install package-x
   - Try building from source: [instructions]
3. Verify installation: package-x --version
4. Report: Status (installed/failed), version, method used

Do NOT stop on first error. Try all alternatives and report results.
```

**Graceful Degradation:**

```markdown
## Required vs Optional Components

### Required (Fail if missing):
- [ ] Docker installed
- [ ] Repository cloned
- [ ] Core model downloaded

### Optional (Continue if missing):
- [ ] MongoDB (service works without it)
- [ ] Additional models (can download later)
- [ ] Optional config file (has defaults)

Report which optional components are missing but CONTINUE deployment.
```

## Performance Optimization Checklist

Use this before starting any deployment:

```markdown
## Pre-Deployment Optimization Review

### Information Gathering
- [ ] All documentation read by agent first
- [ ] Complete requirements list generated
- [ ] All credentials collected upfront
- [ ] All configuration decisions made
- [ ] Dependency graph created

### Task Planning
- [ ] All tasks listed with estimates
- [ ] Dependencies clearly identified
- [ ] Independent tasks grouped for parallelization
- [ ] Resource conflicts identified (GPU, ports, etc.)
- [ ] Verification points planned

### Execution Strategy
- [ ] Maximum parallelization identified
- [ ] Task batches defined (Batch 1, 2, 3...)
- [ ] Polling intervals matched to task duration
- [ ] Failure handling planned for critical paths
- [ ] Rollback strategy defined

### Communication
- [ ] Instructions are explicit and complete
- [ ] Expected outcomes clearly stated
- [ ] Verification steps included
- [ ] Report format specified
- [ ] Success criteria defined

Time Estimate:
- Sequential approach: ___ minutes
- Parallel approach: ___ minutes
- Expected improvement: ___%
```

## Real-World Example: SAM Labeling Deployment

### Deployment A: Unoptimized (40 minutes)

**Mistakes Made:**
- Sequential execution of independent tasks
- SSH key trial-and-error (5 min lost)
- Waited for agent to discover credential needs (5 min lost)
- Fixed 5-second polling for all job types (minor loss)
- Reactive credential management (3 min lost)

**Timeline:**
```
Phase 1: Assessment (3 min)
Phase 2: Repository Setup (8 min)
Phase 3: Ollama Setup (7 min)
Phase 4: RT-DETR Setup (10 min)
Phase 5: Backend Setup (12 min)
Phase 6: Frontend Setup (7 min)
Phase 7: Testing (5 min)
Total: 40 minutes
```

### Deployment B: Optimized (15 minutes)

**Optimizations Applied:**
- All credentials provided upfront
- Correct SSH key used immediately
- Maximum parallelization from start
- Faster polling (3s vs 5s)

**Timeline:**
```
Phase 0: Pre-Planning (2 min)
  - Agent reads all docs
  - User provides all credentials
  - Dependency graph created

Phase 1: Parallel Foundation (2 min)
  ├─ System assessment
  ├─ SSH configuration
  └─ Directory creation
  
Phase 2: Parallel Downloads (4 min)
  ├─ Repository clone
  ├─ SAM models (1.5 GB)
  ├─ RT-DETR model (120 MB)
  └─ Ollama model (4.7 GB)
  
Phase 3: Parallel Services (4 min)
  ├─ Backend + RT-DETR startup
  └─ Frontend build + deploy
  
Phase 4: Integration Test (3 min)
  - Comprehensive health checks
  - Documentation generation

Total: 15 minutes
Improvement: 62% faster
```

**Key Differences:**
```
Unoptimized → Optimized
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
8 min repo    → 4 min (parallel with downloads)
17 min models → 4 min (all parallel)
19 min services → 4 min (backend + frontend parallel)
Multiple credential requests → All upfront
5s polling    → 3s smart polling
```

## Metrics to Track

Track these to measure orchestration effectiveness:

```markdown
## Deployment Metrics

### Time Metrics
- Total deployment time: ___ minutes
- Time per phase: [Phase 1: X min, Phase 2: Y min...]
- Parallel efficiency: (Sequential time / Actual time) = X%
- Communication overhead: ___ round trips

### Quality Metrics
- Tasks completed successfully: X/Y (Z%)
- Tasks requiring retry: X
- Errors requiring human intervention: X
- Average response quality: X/10

### Optimization Metrics
- Parallelization opportunities identified: X
- Parallelization opportunities used: Y
- Potential time savings identified: X min
- Actual time saved: Y min
- Optimization efficiency: (Actual / Potential) = Z%

### Resource Metrics
- Peak GPU utilization: X%
- Peak memory utilization: X%
- Network bandwidth used: X GB
- Disk space consumed: X GB
```

## Advanced Techniques

### Pre-Flight Validation

Before starting lengthy deployments:

```markdown
## Pre-Flight Checklist (2 minutes, saves hours)

Agent should verify:
- [ ] Disk space sufficient (check: df -h)
- [ ] Memory available (check: free -h)
- [ ] GPU availability (check: nvidia-smi)
- [ ] Network connectivity to all sources
- [ ] Credentials valid (test authentication)
- [ ] Required ports available (check: netstat)
- [ ] Dependencies installed (check versions)

If any critical item fails: STOP and report
Do NOT proceed with deployment if fundamentals are broken
```

### Progressive Verification

Catch problems early:

```markdown
## Verification Strategy

Instead of:
1. Do everything
2. Test at the end
3. Discover failure

Do this:
1. Download model
2. → Immediately verify checksum/size
3. → Try loading model
4. → Test basic inference
5. Then proceed to next step

Benefit: Problems found in 2 minutes, not after 30 minutes
```

### Atomic Operations

Reduce round trips:

```markdown
# Instead of separate steps:
1. Create directory
2. CD to directory  
3. Clone repo
4. CD into repo
5. Create config

# Use atomic operations:
1. Clone repo to path (creates path if needed, auto-CDs)
2. Create config in cloned repo

Benefit: Fewer round trips, faster execution
```

## Troubleshooting Guide

### Common Issues and Solutions

**Issue: Agent asks for information multiple times**

Solution:
```markdown
Front-load information gathering:
"Before starting, list EVERYTHING you'll need including:
- All credentials
- All paths/directories
- All configuration values
- All model versions
- All port assignments

Present complete list, I'll provide everything at once."
```

---

**Issue: Tasks running sequentially despite independence**

Solution:
```markdown
Be explicit about parallelization:
"These 3 tasks are INDEPENDENT and should run in PARALLEL:
Task A: [...]
Task B: [...]
Task C: [...]

Launch all 3 simultaneously. Report when ALL complete."
```

---

**Issue: Agent gets stuck on errors**

Solution:
```markdown
Build in error handling:
"If command X fails:
1. Try alternative Y
2. If Y fails, try Z
3. If Z fails, report failure but CONTINUE with next task
Do not stop entire workflow for non-critical failures."
```

---

**Issue: Lost track of what's running**

Solution:
```markdown
Use structured reporting:
"After launching parallel tasks, provide:
- Task A: Job ID, expected duration
- Task B: Job ID, expected duration
- Task C: Job ID, expected duration

I'll monitor these job IDs."
```

---

**Issue: Services conflict on startup**

Solution:
```markdown
Identify resource conflicts upfront:
"These services need GPU:
- Service A: GPU 0
- Service B: GPU 1

These services need ports:
- Service A: 8000
- Service B: 8001

Launch in sequence if conflicts exist, parallel if independent."
```

## Integration with Different Systems

### MCP Server Integration

```markdown
## Using with MCP Remote Agents

Key considerations:
1. Use async job submission for parallel tasks
2. Monitor multiple job IDs simultaneously
3. Handle job status polling efficiently
4. Extract results from completed jobs
5. Handle timeouts gracefully

Example pattern:
# Launch 3 parallel tasks
job1=$(curl POST /chats/{id}/agent-prompt-async -d '{"prompt":"Task A"}')
job2=$(curl POST /chats/{id}/agent-prompt-async -d '{"prompt":"Task B"}')
job3=$(curl POST /chats/{id}/agent-prompt-async -d '{"prompt":"Task C"}')

# Monitor all in parallel
while jobs_not_complete; do
  check_all_job_statuses
  sleep 5
done

# Retrieve all results
result1=$(curl /jobs/{job1})
result2=$(curl /jobs/{job2})
result3=$(curl /jobs/{job3})
```

### SSH-Based Execution

```markdown
## Direct SSH Command Execution

For simpler setups without MCP:

# Launch background tasks
ssh user@host "command1 > /tmp/out1.log 2>&1 &"
ssh user@host "command2 > /tmp/out2.log 2>&1 &"
ssh user@host "command3 > /tmp/out3.log 2>&1 &"

# Monitor completion
while true; do
  status=$(ssh user@host "pgrep -f 'command1|command2|command3' | wc -l")
  if [ "$status" = "0" ]; then break; fi
  sleep 10
done

# Retrieve results
ssh user@host "cat /tmp/out1.log"
ssh user@host "cat /tmp/out2.log"
ssh user@host "cat /tmp/out3.log"
```

### Kubernetes/Container Orchestration

```markdown
## Container-Based Deployments

Apply same principles:

Parallel pod creation:
kubectl apply -f pod1.yaml &
kubectl apply -f pod2.yaml &
kubectl apply -f pod3.yaml &
wait

Parallel readiness checks:
kubectl wait --for=condition=ready pod/pod1 &
kubectl wait --for=condition=ready pod/pod2 &
kubectl wait --for=condition=ready pod/pod3 &
wait

Benefit: Native orchestration + parallel execution
```

## Success Patterns Summary

### The 5 Rules of Effective Agent Orchestration

1. **Front-Load Everything**
   - All docs, all credentials, all decisions - BEFORE starting

2. **Parallelize Aggressively**
   - If tasks are independent, they run together. No exceptions.

3. **Be Explicit**
   - Don't assume. State everything clearly. Agents are literal.

4. **Plan Then Execute**
   - 5 minutes planning saves 15 minutes execution

5. **Verify Progressively**
   - Check critical steps immediately, not at the end

### Quick Decision Framework

**Q: Should I run these tasks in parallel?**
```
Do they share resources? (same GPU, same file, same port)
├─ YES → Run sequentially
└─ NO → Run in parallel
```

**Q: How much detail should I provide?**
```
Would a junior engineer know this?
├─ YES → Brief instruction is fine
└─ NO → Provide explicit, complete details
```

**Q: Should I verify this step?**
```
If this fails, do later steps waste time?
├─ YES → Verify immediately
└─ NO → Verify at final integration test
```

## Future Improvements

Areas for continued optimization:

**1. Automated Dependency Analysis**
```
Tool that:
- Reads task list
- Auto-generates dependency graph
- Suggests optimal parallelization
- Estimates time savings
```

**2. Resource-Aware Scheduling**
```
Scheduler that:
- Knows what resources each task needs
- Automatically prevents conflicts
- Maximizes resource utilization
- Suggests optimal task ordering
```

**3. Agent Learning System**
```
System that:
- Tracks deployment patterns
- Learns from successful optimizations
- Suggests improvements for future deploys
- Auto-applies proven patterns
```

**4. Real-Time Progress Dashboard**
```
Dashboard showing:
- All active jobs and status
- Resource utilization graphs
- Time estimates for completion
- Parallel efficiency metrics
```

## References

Based on real-world deployments:
- **gamer-beta deployment**: 40 minutes (unoptimized)
- **gamer-charlie deployment**: 15 minutes (optimized, 62% faster)
- **Technologies**: SAM 2.1, RT-DETR, Ollama, Docker, FastAPI
- **Infrastructure**: 8x H100 GPUs, 1TB RAM, 14TB storage

Read more:
- [Claude Agent Skills Documentation](https://claude.com/blog/skills)
- Full deployment report: `REMOTE_AGENT_ORCHESTRATION_LEARNINGS.md`

## Version History

- **v1.0** (2025-11-15): Initial skill based on SAM labeling deployments
  - Documented parallel execution patterns
  - Created communication templates
  - Added troubleshooting guide
  - Included real-world metrics

---

**License:** MIT  
**Author:** Learned from production deployments managing remote AI agents  
**Last Updated:** November 15, 2025

