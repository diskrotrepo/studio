"""Tests for the auto-tuning configuration generator."""

import json
import pickle
import tempfile
from pathlib import Path

import pytest

from midi.training.autotune import (
    DatasetInfo,
    HardwareInfo,
    analyze_dataset,
    build_output_dict,
    detect_hardware,
    estimate_model_memory_gb,
    generate_config,
    validate_config,
    _classify_size,
)
from midi.training.config import TrainingConfig


# --- Fixtures for common hardware profiles ---


@pytest.fixture
def a100_40gb():
    return HardwareInfo(
        device_type="cuda",
        device_name="NVIDIA A100-SXM4-40GB",
        gpu_memory_gb=40.0,
        total_memory_gb=256.0,
        gpu_count=1,
        cpu_count=64,
        platform_os="Linux",
    )


@pytest.fixture
def a100_8x():
    return HardwareInfo(
        device_type="cuda",
        device_name="NVIDIA A100-SXM4-40GB",
        gpu_memory_gb=40.0,
        total_memory_gb=512.0,
        gpu_count=8,
        cpu_count=128,
        platform_os="Linux",
    )


@pytest.fixture
def rtx_pro_6000():
    return HardwareInfo(
        device_type="cuda",
        device_name="NVIDIA RTX PRO 6000",
        gpu_memory_gb=96.0,
        total_memory_gb=256.0,
        gpu_count=1,
        cpu_count=64,
        platform_os="Linux",
    )


@pytest.fixture
def m4_max_128gb():
    return HardwareInfo(
        device_type="mps",
        device_name="Apple M4 Max",
        gpu_memory_gb=128.0,
        total_memory_gb=128.0,
        gpu_count=1,
        cpu_count=16,
        platform_os="Darwin",
    )


@pytest.fixture
def cpu_only():
    return HardwareInfo(
        device_type="cpu",
        device_name="CPU",
        gpu_memory_gb=0.0,
        total_memory_gb=32.0,
        gpu_count=0,
        cpu_count=8,
        platform_os="Linux",
    )


@pytest.fixture
def small_dataset():
    return DatasetInfo(
        num_files=200,
        is_multitrack=True,
        size_tier="small",
        source="scan",
    )


@pytest.fixture
def medium_dataset():
    return DatasetInfo(
        num_files=2000,
        is_multitrack=True,
        size_tier="medium",
        seq_length_min=500,
        seq_length_max=12000,
        seq_length_median=6000,
        seq_length_mean=5800,
        total_tokens=11_600_000,
        source="cache",
    )


@pytest.fixture
def large_dataset():
    return DatasetInfo(
        num_files=10000,
        is_multitrack=True,
        size_tier="large",
        source="scan",
    )


# --- Size classification ---


class TestClassifySize:
    def test_small(self):
        assert _classify_size(100) == "small"
        assert _classify_size(499) == "small"

    def test_medium(self):
        assert _classify_size(500) == "medium"
        assert _classify_size(4999) == "medium"

    def test_large(self):
        assert _classify_size(5000) == "large"
        assert _classify_size(50000) == "large"


# --- Hardware detection ---


class TestDetectHardware:
    def test_returns_hardware_info(self):
        hw = detect_hardware()
        assert isinstance(hw, HardwareInfo)
        assert hw.device_type in ("cuda", "mps", "cpu")
        assert hw.cpu_count > 0
        assert hw.total_memory_gb > 0
        assert hw.platform_os in ("Darwin", "Linux", "Windows")


# --- Dataset analysis ---


class TestAnalyzeDataset:
    def test_from_cache(self, tmp_path):
        cache_file = tmp_path / "token_cache.pkl"
        sequences = [
            ([1, 2, 3, 4, 5], [{"track_idx": 0}], [0, 0, 0, 0, 0], [0, 0, 1, 1, 1]),
            ([10, 20, 30], [{"track_idx": 0}], [0, 0, 0], [0, 1, 1]),
        ]
        cache_data = {
            "sequences": sequences,
            "multitrack": True,
            "file_count": 2,
        }
        with open(cache_file, "wb") as f:
            pickle.dump(cache_data, f)

        ds = analyze_dataset(cache_path=str(cache_file))
        assert ds.source == "cache"
        assert ds.num_files == 2
        assert ds.is_multitrack is True
        assert ds.seq_length_min == 3
        assert ds.seq_length_max == 5
        assert ds.total_tokens == 8

    def test_from_midi_dir(self, tmp_path):
        # Create some fake .mid files
        for i in range(10):
            (tmp_path / f"test_{i}.mid").write_bytes(b"\x00")

        ds = analyze_dataset(midi_dir=str(tmp_path))
        assert ds.source == "scan"
        assert ds.num_files == 10
        assert ds.size_tier == "small"
        assert ds.seq_length_min is None  # no cache stats

    def test_empty_dir_raises(self, tmp_path):
        with pytest.raises(ValueError, match="No MIDI files"):
            analyze_dataset(midi_dir=str(tmp_path))

    def test_no_inputs_raises(self):
        with pytest.raises(ValueError, match="At least one"):
            analyze_dataset()

    def test_cache_with_single_track(self, tmp_path):
        cache_file = tmp_path / "cache.pkl"
        sequences = [[1, 2, 3], [4, 5, 6, 7]]
        cache_data = {
            "sequences": sequences,
            "multitrack": False,
            "file_count": 2,
        }
        with open(cache_file, "wb") as f:
            pickle.dump(cache_data, f)

        ds = analyze_dataset(cache_path=str(cache_file))
        assert ds.is_multitrack is False
        assert ds.seq_length_min == 3
        assert ds.seq_length_max == 4


# --- Memory estimation ---


class TestEstimateModelMemory:
    def test_returns_positive(self):
        mem = estimate_model_memory_gb()
        assert mem > 0

    def test_scales_with_batch_size(self):
        mem_small = estimate_model_memory_gb(batch_size=1)
        mem_large = estimate_model_memory_gb(batch_size=16)
        assert mem_large > mem_small

    def test_scales_with_layers(self):
        mem_6 = estimate_model_memory_gb(n_layers=6)
        mem_12 = estimate_model_memory_gb(n_layers=12)
        assert mem_12 > mem_6


# --- Config generation: A100 40GB + small dataset ---


class TestGenerateConfigA100Small:
    def test_matches_preset_pattern(self, a100_40gb, small_dataset):
        config = generate_config(a100_40gb, small_dataset)

        assert config["d_model"] == 512
        assert config["n_heads"] == 8
        assert config["n_layers"] == 12
        assert config["seq_length"] == 8192
        assert config["batch_size_per_gpu"] == 12
        assert config["learning_rate"] == 5e-5
        assert config["dropout"] == 0.2
        assert config["warmup_pct"] == 0.15
        assert config["epochs"] == 20
        assert config["early_stopping_patience"] == 5
        assert config["use_compile"] is True

    def test_validates_through_training_config(self, a100_40gb, small_dataset):
        config = generate_config(a100_40gb, small_dataset)
        tc = validate_config(config)
        assert isinstance(tc, TrainingConfig)


# --- Config generation: 8x A100 ---


class TestGenerateConfig8xA100:
    def test_multi_gpu_adjustments(self, a100_8x, small_dataset):
        config = generate_config(a100_8x, small_dataset)

        # batch_size should be reduced for multi-GPU
        assert config["batch_size_per_gpu"] <= 12
        assert config["batch_size_per_gpu"] >= 2
        # gradient accumulation should be lower since world_size=8
        assert config["gradient_accumulation"] <= 5
        assert config["use_compile"] is True
        assert config["distributed_timeout_minutes"] == 60

    def test_large_dataset_multi_gpu(self, a100_8x, large_dataset):
        config = generate_config(a100_8x, large_dataset)

        assert config["epochs"] == 8
        assert config["early_stopping_patience"] == 3
        assert config["learning_rate"] == 3e-4


# --- Config generation: RTX PRO 6000 ---


class TestGenerateConfigRTXPro:
    def test_high_memory_gpu(self, rtx_pro_6000, medium_dataset):
        config = generate_config(rtx_pro_6000, medium_dataset)

        assert config["batch_size_per_gpu"] == 24
        assert config["learning_rate"] == 1e-4  # higher LR for big GPU + medium data
        assert config["epochs"] == 30
        assert config["seq_length"] == 8192


# --- Config generation: M4 Max MPS ---


class TestGenerateConfigMPS:
    def test_mps_settings(self, m4_max_128gb, small_dataset):
        config = generate_config(m4_max_128gb, small_dataset)

        assert config["seq_length"] == 2048
        assert config["use_compile"] is False
        assert config["batch_size_per_gpu"] == 16
        assert config["d_model"] == 512

    def test_validates(self, m4_max_128gb, small_dataset):
        config = generate_config(m4_max_128gb, small_dataset)
        tc = validate_config(config)
        assert isinstance(tc, TrainingConfig)


# --- Config generation: CPU fallback ---


class TestGenerateConfigCPU:
    def test_cpu_uses_small_model(self, cpu_only, small_dataset):
        config = generate_config(cpu_only, small_dataset)

        assert config["d_model"] == 256
        assert config["n_heads"] == 4
        assert config["n_layers"] == 6
        assert config["seq_length"] == 1024
        assert config["use_compile"] is False
        assert config["batch_size_per_gpu"] == 2

    def test_validates(self, cpu_only, small_dataset):
        config = generate_config(cpu_only, small_dataset)
        tc = validate_config(config)
        assert isinstance(tc, TrainingConfig)


# --- Dataset size tier effects ---


class TestDatasetSizeTiers:
    def test_small_vs_large_dropout(self, a100_40gb, small_dataset, large_dataset):
        small_cfg = generate_config(a100_40gb, small_dataset)
        large_cfg = generate_config(a100_40gb, large_dataset)

        assert small_cfg["dropout"] > large_cfg["dropout"]

    def test_small_vs_large_lr(self, a100_40gb, small_dataset, large_dataset):
        small_cfg = generate_config(a100_40gb, small_dataset)
        large_cfg = generate_config(a100_40gb, large_dataset)

        assert small_cfg["learning_rate"] < large_cfg["learning_rate"]

    def test_small_vs_large_epochs(self, a100_40gb, small_dataset, large_dataset):
        small_cfg = generate_config(a100_40gb, small_dataset)
        large_cfg = generate_config(a100_40gb, large_dataset)

        assert small_cfg["epochs"] > large_cfg["epochs"]


# --- Output building and JSON compatibility ---


class TestOutputAndValidation:
    def test_build_output_dict_has_metadata(self, a100_40gb, small_dataset):
        config = generate_config(a100_40gb, small_dataset)
        output = build_output_dict(config, a100_40gb, small_dataset)

        assert "_description" in output
        assert "_hardware" in output
        assert "_dataset_info" in output
        assert output["_hardware"]["device_type"] == "cuda"
        assert output["_dataset_info"]["size_tier"] == "small"

    def test_output_loads_via_training_config(self, a100_40gb, small_dataset, tmp_path):
        config = generate_config(a100_40gb, small_dataset)
        output = build_output_dict(config, a100_40gb, small_dataset)

        json_path = tmp_path / "test_config.json"
        with open(json_path, "w") as f:
            json.dump(output, f)

        # This is the critical test: TrainingConfig.from_json must accept the output
        tc = TrainingConfig.from_json(str(json_path))
        assert tc.d_model == config["d_model"]
        assert tc.batch_size_per_gpu == config["batch_size_per_gpu"]
        assert tc.learning_rate == config["learning_rate"]

    def test_all_training_config_fields_present(self, a100_40gb, small_dataset):
        config = generate_config(a100_40gb, small_dataset)
        import dataclasses

        expected_fields = {f.name for f in dataclasses.fields(TrainingConfig)}
        config_fields = {k for k in config if not k.startswith("_")}
        assert config_fields == expected_fields

    def test_description_includes_hardware(self, a100_40gb, small_dataset):
        config = generate_config(a100_40gb, small_dataset)
        output = build_output_dict(config, a100_40gb, small_dataset)

        desc = output["_description"]
        assert "A100" in desc
        assert "auto-tuned" in desc
