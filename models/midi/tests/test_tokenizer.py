"""Tests for tokenizer core and tag system."""
import pytest

from midi.tokenization.tags import (
    GENRE_TAGS,
    MOOD_TAGS,
    TEMPO_TAGS,
    KEY_TAGS,
    TIMESIG_TAGS,
    DENSITY_TAGS,
    ALL_TAGS,
    discover_genres,
    discover_artists,
    get_all_tags,
    get_available_tags,
)
from midi.tokenization import (
    MULTITRACK_TOKENS,
    TRACK_TYPE_TOKENS,
    MAX_TRACKS,
    get_tokenizer,
    get_tag_tokens,
    parse_tags,
)


class TestTagConstants:
    """Tests for tag constant lists."""

    def test_genre_tags_non_empty(self):
        assert len(GENRE_TAGS) > 0

    def test_mood_tags_non_empty(self):
        assert len(MOOD_TAGS) > 0

    def test_tempo_tags_non_empty(self):
        assert len(TEMPO_TAGS) > 0

    def test_all_tags_prefixed(self):
        for tag in ALL_TAGS:
            assert "_" in tag, f"Tag {tag} should have a category prefix"

    def test_all_tags_uppercase(self):
        for tag in ALL_TAGS:
            assert tag == tag.upper(), f"Tag {tag} should be uppercase"

    def test_get_all_tags_includes_all_categories(self):
        tags = get_all_tags(include_artists=False)
        prefixes = {t.split("_")[0] for t in tags}
        expected = {"GENRE", "MOOD", "TEMPO", "KEY", "TIMESIG", "DENSITY",
                    "DYNAMICS", "LENGTH", "REGISTER", "ARRANGEMENT", "RHYTHM",
                    "HARMONY", "ARTICULATION", "EXPRESSION", "ERA"}
        assert prefixes == expected

    def test_get_available_tags_returns_dict(self):
        result = get_available_tags()
        assert isinstance(result, dict)
        assert "genre" in result
        assert "mood" in result
        assert "tempo" in result


class TestDiscovery:
    """Tests for genre/artist discovery with nonexistent dirs."""

    def test_discover_genres_missing_dir(self):
        assert discover_genres("/nonexistent/path") == []

    def test_discover_artists_missing_dir(self):
        assert discover_artists("/nonexistent/path") == []


class TestTokenizerCore:
    """Tests for tokenizer creation and tag parsing."""

    @pytest.fixture(scope="class")
    def tokenizer(self):
        return get_tokenizer()

    def test_tokenizer_has_special_tokens(self, tokenizer):
        for name in ["PAD", "BOS", "EOS"]:
            assert any(name in k for k in tokenizer.vocab), f"Missing {name} token"

    def test_tokenizer_has_multitrack_tokens(self, tokenizer):
        for name in MULTITRACK_TOKENS:
            assert name in tokenizer.vocab, f"Missing {name} token"

    def test_tokenizer_has_track_type_tokens(self, tokenizer):
        for name in TRACK_TYPE_TOKENS:
            assert name in tokenizer.vocab, f"Missing {name} token"

    def test_max_tracks_positive(self):
        assert MAX_TRACKS > 0

    def test_get_tag_tokens_returns_dict(self, tokenizer):
        tags = get_tag_tokens(tokenizer)
        assert isinstance(tags, dict)
        assert len(tags) > 0

    def test_parse_tags_known_genre(self, tokenizer):
        ids = parse_tags("jazz", tokenizer)
        assert len(ids) == 1

    def test_parse_tags_multiple(self, tokenizer):
        ids = parse_tags("jazz happy fast", tokenizer)
        assert len(ids) == 3

    def test_parse_tags_unknown(self, tokenizer):
        ids = parse_tags("xyznonexistent", tokenizer)
        assert len(ids) == 0

    def test_parse_tags_empty(self, tokenizer):
        ids = parse_tags("", tokenizer)
        assert len(ids) == 0


class TestLastfmTagMapping:
    """Tests for Last.fm tag to tokenizer vocabulary mapping."""

    def test_hiphop_variants_dedup(self):
        from midi.tokenization.lastfm_tags import map_lastfm_tags
        result = map_lastfm_tags("hip-hop,rap,hip hop,hiphop")
        assert result["genres"] == ["GENRE_HIP_HOP"]

    def test_multiple_genres(self):
        from midi.tokenization.lastfm_tags import map_lastfm_tags
        result = map_lastfm_tags("hip-hop,pop,electronic")
        assert result["genres"] == ["GENRE_HIP_HOP", "GENRE_POP", "GENRE_ELECTRONIC"]

    def test_mood_extraction(self):
        from midi.tokenization.lastfm_tags import map_lastfm_tags
        result = map_lastfm_tags("rock,happy,energetic")
        assert result["genres"] == ["GENRE_ROCK"]
        assert "MOOD_HAPPY" in result["moods"]
        assert "MOOD_ENERGETIC" in result["moods"]

    def test_noise_tags_ignored(self):
        from midi.tokenization.lastfm_tags import map_lastfm_tags
        result = map_lastfm_tags("some artist,random tag,chicago,american")
        assert result["genres"] == []
        assert result["moods"] == []

    def test_empty_string(self):
        from midi.tokenization.lastfm_tags import map_lastfm_tags
        result = map_lastfm_tags("")
        assert result["genres"] == []
        assert result["moods"] == []

    def test_preserves_order(self):
        from midi.tokenization.lastfm_tags import map_lastfm_tags
        result = map_lastfm_tags("electronic,pop,rock")
        assert result["genres"] == ["GENRE_ELECTRONIC", "GENRE_POP", "GENRE_ROCK"]

    def test_real_lastfm_data(self):
        from midi.tokenization.lastfm_tags import map_lastfm_tags
        result = map_lastfm_tags(
            "hip-hop,rap,hip hop,rnb,some artist,random tag,pop,american,chicago,electronic"
        )
        assert result["genres"][0] == "GENRE_HIP_HOP"
        assert "GENRE_R&B_SOUL" in result["genres"]
        assert "GENRE_POP" in result["genres"]
        assert "GENRE_ELECTRONIC" in result["genres"]


class TestMetadataInference:
    """Tests for metadata-based tag inference."""

    def test_infer_from_metadata(self):
        from pathlib import Path
        from midi.tokenization.tag_inference import infer_tags_from_metadata
        metadata = {
            "TRACK123_abcd1234.mid": {
                "genres": ["GENRE_ROCK", "GENRE_POP"],
                "moods": ["MOOD_HAPPY"],
            }
        }
        tags = infer_tags_from_metadata(Path("TRACK123_abcd1234.mid"), metadata)
        assert tags == ["GENRE_ROCK", "GENRE_POP", "MOOD_HAPPY"]

    def test_missing_file_returns_empty(self):
        from pathlib import Path
        from midi.tokenization.tag_inference import infer_tags_from_metadata
        tags = infer_tags_from_metadata(Path("nonexistent.mid"), {})
        assert tags == []

    def test_empty_genres_moods(self):
        from pathlib import Path
        from midi.tokenization.tag_inference import infer_tags_from_metadata
        metadata = {
            "test.mid": {"genres": [], "moods": []}
        }
        tags = infer_tags_from_metadata(Path("test.mid"), metadata)
        assert tags == []
