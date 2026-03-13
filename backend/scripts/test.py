#!/usr/bin/env python
"""Testing helper script"""

import subprocess
import sys


def run_tests():
    """Run all tests with coverage"""
    subprocess.run(["uv", "run", "pytest", "--disable-warnings", "--maxfail=1"])


def run_tests_parallel():
    """Run tests in parallel"""
    subprocess.run(["uv", "run", "pytest", "--disable-warnings", "-n", "auto"])


def coverage_report():
    """Generate coverage report"""
    subprocess.run(["uv", "run", "coverage", "run", "-m", "pytest"])
    subprocess.run(["uv", "run", "coverage", "report", "-m"])
    subprocess.run(["uv", "run", "coverage", "html"])
    print("Coverage HTML report generated in htmlcov/")


def test_specific(test_path):
    """Run specific test"""
    subprocess.run(["uv", "run", "pytest", "--disable-warnings", test_path, "-v"])


if __name__ == "__main__":
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "test":
            run_tests()
        elif command == "test-parallel":
            run_tests_parallel()
        elif command == "coverage":
            coverage_report()
        elif command == "specific" and len(sys.argv) > 2:
            test_specific(sys.argv[2])
        else:
            print("Available commands: test, test-parallel, coverage, specific <test_path>")
    else:
        print("Available commands: test, test-parallel, coverage, specific <test_path>")
