"""
Logging infrastructure for cursor-agent experiments
"""
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

# Setup logging
log_dir = Path(__file__).parent / "logs"
log_dir.mkdir(exist_ok=True)

log_file = log_dir / f"experiments_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger("cursor-agent-experiments")


class ExperimentTracker:
    """Track experiment results"""
    
    def __init__(self, experiment_name: str):
        self.experiment_name = experiment_name
        self.results = []
        self.start_time = datetime.now()
        
    def log_test(self, test_name: str, success: bool, details: Dict[str, Any], 
                 error: Optional[str] = None):
        """Log a test result"""
        result = {
            "test_name": test_name,
            "success": success,
            "details": details,
            "error": error,
            "timestamp": datetime.now().isoformat()
        }
        self.results.append(result)
        
        if success:
            logger.info(f"✓ {test_name}: PASSED")
        else:
            logger.error(f"✗ {test_name}: FAILED - {error}")
            
        logger.debug(f"Details: {json.dumps(details, indent=2)}")
    
    def save_results(self):
        """Save all results to JSON file"""
        output_file = log_dir / f"{self.experiment_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        summary = {
            "experiment": self.experiment_name,
            "start_time": self.start_time.isoformat(),
            "end_time": datetime.now().isoformat(),
            "total_tests": len(self.results),
            "passed": sum(1 for r in self.results if r["success"]),
            "failed": sum(1 for r in self.results if not r["success"]),
            "results": self.results
        }
        
        with open(output_file, 'w') as f:
            json.dump(summary, f, indent=2)
        
        logger.info(f"\nExperiment complete: {self.experiment_name}")
        logger.info(f"Total tests: {summary['total_tests']}")
        logger.info(f"Passed: {summary['passed']}")
        logger.info(f"Failed: {summary['failed']}")
        logger.info(f"Results saved to: {output_file}")
        
        return summary

