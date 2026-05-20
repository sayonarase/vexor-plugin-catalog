#!/usr/bin/env python3

import argparse
import subprocess
import sys
import re

def parse_niping_output(output):
    """
    Parse the output of the niping command and extract metrics.

    Returns:
        avg (float): Average response time.
        max_ (float): Maximum response time.
        min_ (float): Minimum response time.
        tr (float): Transfer rate (kB/s).
        av2 (float): Average response time excluding max and min.
        tr2 (float): Transfer rate excluding max and min (kB/s).
    """

    # Initialize all metrics as None
    avg = max_ = min_ = tr = av2 = tr2 = None
    for line in output.splitlines():
        if line.startswith('avg'):
            avg = float(re.search(r"avg\s+([0-9.]+)", line).group(1))
        elif line.startswith('max'):
            max_ = float(re.search(r"max\s+([0-9.]+)", line).group(1))
        elif line.startswith('min'):
            min_ = float(re.search(r"min\s+([0-9.]+)", line).group(1))
        elif line.startswith('tr'):
            tr_match = re.search(r"tr\s+([0-9.]+)", line)
            if tr_match and 'tr2' not in line:
                tr = float(tr_match.group(1))
        elif line.startswith('av2'):
            av2 = float(re.search(r"av2\s+([0-9.]+)", line).group(1))
        elif line.startswith('tr2'):
            tr2 = float(re.search(r"tr2\s+([0-9.]+)", line).group(1))
    return avg, max_, min_, tr, av2, tr2

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Nagios plugin to check SAP 'niping' response times and all metrics."
    )
    parser.add_argument('-H', '--host', required=True, help='Target host for niping')
    parser.add_argument('-D', '--delay', default='200', help='Delay between sends (default: 200)')
    parser.add_argument('-L', '--loop', default='10', help='Number of loops (default: 10)')
    parser.add_argument('-w', '--warning', type=float, default=500.0, help='Warning threshold for avg ms')
    parser.add_argument('-c', '--critical', type=float, default=1000.0, help='Critical threshold for avg ms')
    parser.add_argument('--niping-path', default='niping', help='Path to niping binary (default: niping)')
    args = parser.parse_args()

    cmd = [
        args.niping_path, '-c',
        '-H', args.host,
        '-D', str(args.delay),
        '-L', str(args.loop),
        '-P'
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except Exception as e:
        print(f"UNKNOWN - Failed to run niping: {e}")
        sys.exit(3)

    if result.returncode != 0:
        print(f"CRITICAL - niping command failed: {result.stderr.strip()}")
        sys.exit(2)

    avg, max_, min_, tr, av2, tr2 = parse_niping_output(result.stdout)
    if avg is None:
        print("UNKNOWN - Could not parse niping output")
        sys.exit(3)

    # Build the performance data string, only including metrics that were parsed
    perf_data = f"avg={avg:.3f}ms;{args.warning};{args.critical} max={max_:.3f}ms min={min_:.3f}ms"
    if tr is not None:
        perf_data += f" tr={tr:.3f}kBps"
    if av2 is not None:
        perf_data += f" av2={av2:.3f}ms"
    if tr2 is not None:
        perf_data += f" tr2={tr2:.3f}kBps"

    message = f"NIPING avg={avg:.3f}ms max={max_:.3f}ms min={min_:.3f}ms"
    if tr is not None:
        message += f" tr={tr:.3f}kBps"
    if av2 is not None:
        message += f" av2={av2:.3f}ms"
    if tr2 is not None:
        message += f" tr2={tr2:.3f}kBps"
    message += f" | {perf_data}"

    if avg >= args.critical:
        print(f"CRITICAL - {message}")
        sys.exit(2)
    elif avg >= args.warning:
        print(f"WARNING - {message}")
        sys.exit(1)
    else:
        print(f"OK - {message}")
        sys.exit(0)