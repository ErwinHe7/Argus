from __future__ import annotations

import json
import sys
import time


def main() -> int:
    import torch

    report: dict[str, object] = {
        "python": sys.version.split()[0],
        "torch": torch.__version__,
        "torch_cuda_build": torch.version.cuda,
        "cuda_available": torch.cuda.is_available(),
        "device_count": torch.cuda.device_count(),
    }
    if not torch.cuda.is_available():
        report["status"] = "FAILED_CUDA_UNAVAILABLE"
        print(json.dumps(report, sort_keys=True))
        return 2

    device = torch.device("cuda:0")
    properties = torch.cuda.get_device_properties(device)
    report.update(
        {
            "device": properties.name,
            "compute_capability": list(torch.cuda.get_device_capability(device)),
            "total_memory_bytes": properties.total_memory,
            "bf16_supported": torch.cuda.is_bf16_supported(),
        }
    )

    torch.manual_seed(7)
    started = time.perf_counter()
    left = torch.randn((2048, 2048), device=device, dtype=torch.float32, requires_grad=True)
    right = torch.randn((2048, 2048), device=device, dtype=torch.float32)
    loss = (left @ right).square().mean()
    loss.backward()
    torch.cuda.synchronize(device)
    elapsed = time.perf_counter() - started

    finite = bool(torch.isfinite(loss).item() and torch.isfinite(left.grad).all().item())
    report.update(
        {
            "status": "PASSED" if finite else "FAILED_NON_FINITE",
            "matmul_backward_seconds": round(elapsed, 4),
            "allocated_memory_bytes": torch.cuda.memory_allocated(device),
            "peak_memory_bytes": torch.cuda.max_memory_allocated(device),
        }
    )
    print(json.dumps(report, sort_keys=True))
    return 0 if finite else 3


if __name__ == "__main__":
    raise SystemExit(main())
