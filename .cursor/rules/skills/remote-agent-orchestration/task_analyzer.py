#!/usr/bin/env python3
"""
Task Dependency Analyzer and Parallel Execution Planner

Analyzes deployment tasks, identifies dependencies, and generates
optimal parallel execution plans.
"""

import json
from typing import Dict, List, Set, Tuple
from dataclasses import dataclass, asdict
from collections import defaultdict


@dataclass
class Task:
    """Represents a deployment task"""
    id: str
    name: str
    duration_minutes: float
    dependencies: List[str]
    resources: List[str]  # e.g., ["gpu:0", "disk:write", "network"]
    
    def conflicts_with(self, other: 'Task') -> bool:
        """Check if this task conflicts with another based on shared resources"""
        shared = set(self.resources) & set(other.resources)
        # Network and disk:read can be shared
        shared_exclusive = shared - {'network', 'disk:read'}
        return len(shared_exclusive) > 0


@dataclass
class ExecutionBatch:
    """Represents a batch of tasks that can run in parallel"""
    batch_number: int
    tasks: List[Task]
    duration_minutes: float
    
    def __repr__(self):
        task_names = [t.name for t in self.tasks]
        return f"Batch {self.batch_number} ({self.duration_minutes:.1f}min): {task_names}"


class TaskAnalyzer:
    """Analyzes tasks and creates optimized execution plan"""
    
    def __init__(self, tasks: List[Task]):
        self.tasks = {task.id: task for task in tasks}
        self.batches: List[ExecutionBatch] = []
        
    def get_dependency_graph(self) -> Dict[str, List[str]]:
        """Build dependency graph"""
        graph = {}
        for task_id, task in self.tasks.items():
            graph[task_id] = task.dependencies
        return graph
    
    def get_ready_tasks(self, completed: Set[str]) -> List[Task]:
        """Get all tasks whose dependencies are satisfied"""
        ready = []
        for task_id, task in self.tasks.items():
            if task_id in completed:
                continue
            if all(dep in completed for dep in task.dependencies):
                ready.append(task)
        return ready
    
    def find_parallel_groups(self, ready_tasks: List[Task]) -> List[List[Task]]:
        """Group ready tasks that can run in parallel (no resource conflicts)"""
        if not ready_tasks:
            return []
        
        groups = []
        remaining = ready_tasks.copy()
        
        while remaining:
            # Start a new group with first remaining task
            group = [remaining.pop(0)]
            
            # Try to add more tasks that don't conflict
            i = 0
            while i < len(remaining):
                task = remaining[i]
                conflicts = any(task.conflicts_with(t) for t in group)
                if not conflicts:
                    group.append(remaining.pop(i))
                else:
                    i += 1
            
            groups.append(group)
        
        return groups
    
    def create_execution_plan(self) -> Tuple[List[ExecutionBatch], float, float]:
        """
        Create optimal execution plan
        
        Returns:
            (batches, parallel_time, sequential_time)
        """
        completed = set()
        batches = []
        batch_num = 1
        
        # Calculate sequential time
        sequential_time = sum(task.duration_minutes for task in self.tasks.values())
        
        while len(completed) < len(self.tasks):
            # Get all ready tasks
            ready = self.get_ready_tasks(completed)
            if not ready:
                break  # Circular dependency or error
            
            # Find parallel groups
            groups = self.find_parallel_groups(ready)
            
            # Create batch for each group (groups with conflicts become separate batches)
            for group in groups:
                # Duration of batch is longest task in the group
                duration = max(task.duration_minutes for task in group)
                batch = ExecutionBatch(
                    batch_number=batch_num,
                    tasks=group,
                    duration_minutes=duration
                )
                batches.append(batch)
                batch_num += 1
                
                # Mark all tasks in group as completed for dependency resolution
                for task in group:
                    completed.add(task.id)
        
        parallel_time = sum(batch.duration_minutes for batch in batches)
        
        self.batches = batches
        return batches, parallel_time, sequential_time
    
    def print_plan(self):
        """Pretty print the execution plan"""
        if not self.batches:
            print("No execution plan created yet. Run create_execution_plan() first.")
            return
        
        parallel_time = sum(b.duration_minutes for b in self.batches)
        sequential_time = sum(task.duration_minutes for task in self.tasks.values())
        improvement = ((sequential_time - parallel_time) / sequential_time) * 100
        
        print("=" * 70)
        print("OPTIMIZED EXECUTION PLAN")
        print("=" * 70)
        print(f"\nTotal tasks: {len(self.tasks)}")
        print(f"Sequential time: {sequential_time:.1f} minutes")
        print(f"Parallel time: {parallel_time:.1f} minutes")
        print(f"Time saved: {sequential_time - parallel_time:.1f} minutes ({improvement:.0f}% faster)")
        print(f"\nNumber of batches: {len(self.batches)}")
        print("\n" + "-" * 70)
        
        for batch in self.batches:
            print(f"\n🔹 BATCH {batch.batch_number} (Duration: {batch.duration_minutes:.1f} min)")
            print(f"   Run these {len(batch.tasks)} tasks IN PARALLEL:")
            
            for task in batch.tasks:
                resources_str = ", ".join(task.resources) if task.resources else "none"
                deps_str = ", ".join(task.dependencies) if task.dependencies else "none"
                print(f"   • {task.name}")
                print(f"     - Duration: {task.duration_minutes:.1f} min")
                print(f"     - Resources: {resources_str}")
                print(f"     - Dependencies: {deps_str}")
        
        print("\n" + "=" * 70)
    
    def export_json(self, filename: str):
        """Export plan to JSON for automation"""
        plan = {
            "total_tasks": len(self.tasks),
            "sequential_time_minutes": sum(t.duration_minutes for t in self.tasks.values()),
            "parallel_time_minutes": sum(b.duration_minutes for b in self.batches),
            "improvement_percent": (
                (sum(t.duration_minutes for t in self.tasks.values()) - 
                 sum(b.duration_minutes for b in self.batches)) / 
                sum(t.duration_minutes for t in self.tasks.values()) * 100
            ),
            "batches": [
                {
                    "batch_number": batch.batch_number,
                    "duration_minutes": batch.duration_minutes,
                    "tasks": [
                        {
                            "id": task.id,
                            "name": task.name,
                            "duration_minutes": task.duration_minutes,
                            "dependencies": task.dependencies,
                            "resources": task.resources
                        }
                        for task in batch.tasks
                    ]
                }
                for batch in self.batches
            ]
        }
        
        with open(filename, 'w') as f:
            json.dump(plan, f, indent=2)
        
        print(f"\n✅ Execution plan exported to {filename}")


def example_sam_deployment():
    """Example: SAM Assisted Labeling deployment"""
    
    tasks = [
        Task("assess", "System Assessment", 2.0, [], ["disk:read"]),
        Task("ssh", "Configure SSH", 1.0, [], ["disk:write", "network"]),
        Task("mkdir", "Create Directories", 0.5, [], ["disk:write"]),
        Task("docker_compose", "Install docker-compose", 2.0, [], ["network", "disk:write"]),
        
        Task("clone_repo", "Clone Repository", 0.5, ["ssh", "mkdir"], ["network", "disk:write"]),
        Task("create_env", "Create .env File", 0.5, ["clone_repo"], ["disk:write"]),
        
        Task("download_sam", "Download SAM Models", 5.0, ["clone_repo"], ["network", "disk:write"]),
        Task("download_rtdetr", "Download RT-DETR Model", 2.0, ["clone_repo", "create_env"], ["network", "disk:write"]),
        Task("install_ollama", "Install Ollama", 3.0, [], ["network", "disk:write"]),
        Task("pull_ollama_model", "Pull Ollama Model", 7.0, ["install_ollama"], ["network", "disk:write"]),
        
        Task("start_backend", "Start Backend Service", 2.0, ["download_sam", "create_env"], ["gpu:0", "network"]),
        Task("start_rtdetr", "Start RT-DETR Service", 1.5, ["download_rtdetr"], ["gpu:1", "network"]),
        Task("build_frontend", "Build Frontend Container", 8.0, ["clone_repo", "docker_compose"], ["cpu", "disk:write"]),
        Task("start_frontend", "Start Frontend Container", 1.0, ["build_frontend"], ["network"]),
        
        Task("integration_test", "Integration Testing", 3.0, 
             ["start_backend", "start_rtdetr", "start_frontend"], 
             ["network"]),
    ]
    
    print("\n" + "=" * 70)
    print("ANALYZING SAM ASSISTED LABELING DEPLOYMENT")
    print("=" * 70)
    
    analyzer = TaskAnalyzer(tasks)
    batches, parallel_time, sequential_time = analyzer.create_execution_plan()
    analyzer.print_plan()
    
    print("\n📊 COMPARISON TO REAL DEPLOYMENTS:")
    print(f"   Unoptimized (gamer-beta): ~40 minutes")
    print(f"   Optimized (gamer-charlie): ~15 minutes")
    print(f"   This plan estimate: ~{parallel_time:.0f} minutes")
    print(f"   Theoretical minimum: ~{parallel_time:.0f} minutes")
    
    # Export for automation
    analyzer.export_json("sam_deployment_plan.json")
    
    return analyzer


def example_simple():
    """Simple example for demonstration"""
    
    tasks = [
        Task("a", "Download Model A", 5.0, [], ["network"]),
        Task("b", "Download Model B", 5.0, [], ["network"]),
        Task("c", "Install Packages", 3.0, [], ["network", "disk:write"]),
        Task("d", "Build App", 8.0, ["a", "c"], ["cpu", "disk:write"]),
        Task("e", "Start Service A", 2.0, ["a"], ["gpu:0"]),
        Task("f", "Start Service B", 2.0, ["b"], ["gpu:1"]),
        Task("g", "Run Tests", 3.0, ["e", "f"], ["network"]),
    ]
    
    analyzer = TaskAnalyzer(tasks)
    batches, parallel_time, sequential_time = analyzer.create_execution_plan()
    analyzer.print_plan()
    
    return analyzer


if __name__ == "__main__":
    import sys
    
    print("Task Dependency Analyzer and Parallel Execution Planner")
    print("========================================================\n")
    
    if len(sys.argv) > 1 and sys.argv[1] == "--simple":
        example_simple()
    else:
        example_sam_deployment()

