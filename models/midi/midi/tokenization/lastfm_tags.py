"""
Mapping from free-form Last.fm tags to the tokenizer's structured tag vocabulary.

Last.fm tags are noisy (artist names, locations, inside jokes) and inconsistent
("hip-hop" vs "hip hop" vs "hiphop"). This module maps them to the canonical
GENRE_* and MOOD_* tokens defined in tags.py.
"""

# Many-to-one mapping: Last.fm tag string -> tokenizer genre token
LASTFM_GENRE_MAP: dict[str, str] = {
    # Rock
    "rock": "GENRE_ROCK",
    "classic rock": "GENRE_ROCK",
    "alternative rock": "GENRE_ROCK",
    "indie rock": "GENRE_ROCK",
    "alternative": "GENRE_ROCK",
    "grunge": "GENRE_ROCK",
    "post-punk": "GENRE_ROCK",
    "punk rock": "GENRE_ROCK",
    "punk": "GENRE_ROCK",
    "pop rock": "GENRE_ROCK",
    "hard rock": "GENRE_ROCK",
    "garage rock": "GENRE_ROCK",
    "psychedelic rock": "GENRE_ROCK",
    "psychedelic": "GENRE_ROCK",
    "progressive rock": "GENRE_ROCK",
    "britpop": "GENRE_ROCK",
    "new wave": "GENRE_ROCK",
    "post-rock": "GENRE_ROCK",
    "emo": "GENRE_ROCK",
    "shoegaze": "GENRE_ROCK",
    "indie": "GENRE_ROCK",
    "stoner rock": "GENRE_ROCK",
    "rockabilly": "GENRE_ROCK",
    "post-hardcore": "GENRE_ROCK",
    "christian rock": "GENRE_ROCK",

    # Metal
    "metal": "GENRE_METAL",
    "heavy metal": "GENRE_METAL",
    "death metal": "GENRE_METAL",
    "melodic death metal": "GENRE_METAL",
    "black metal": "GENRE_METAL",
    "thrash metal": "GENRE_METAL",
    "nu metal": "GENRE_METAL",
    "metalcore": "GENRE_METAL",
    "doom metal": "GENRE_METAL",
    "gothic metal": "GENRE_METAL",
    "gothic rock": "GENRE_METAL",
    "power metal": "GENRE_METAL",
    "symphonic metal": "GENRE_METAL",
    "progressive metal": "GENRE_METAL",
    "hardcore": "GENRE_METAL",
    "grindcore": "GENRE_METAL",
    "industrial": "GENRE_METAL",

    # Pop
    "pop": "GENRE_POP",
    "dance-pop": "GENRE_POP",
    "synth-pop": "GENRE_POP",
    "synthpop": "GENRE_POP",
    "electropop": "GENRE_POP",
    "teen pop": "GENRE_POP",
    "bubblegum pop": "GENRE_POP",
    "k-pop": "GENRE_POP",
    "j-pop": "GENRE_POP",
    "indie pop": "GENRE_POP",
    "80s": "GENRE_POP",
    "oldies": "GENRE_POP",
    "60s": "GENRE_POP",
    "70s": "GENRE_POP",

    # Electronic
    "electronic": "GENRE_ELECTRONIC",
    "electronica": "GENRE_ELECTRONIC",
    "electro": "GENRE_ELECTRONIC",
    "techno": "GENRE_ELECTRONIC",
    "house": "GENRE_ELECTRONIC",
    "trance": "GENRE_ELECTRONIC",
    "edm": "GENRE_ELECTRONIC",
    "drum and bass": "GENRE_ELECTRONIC",
    "dubstep": "GENRE_ELECTRONIC",
    "dance": "GENRE_ELECTRONIC",
    "eurodance": "GENRE_ELECTRONIC",
    "idm": "GENRE_ELECTRONIC",
    "breakbeat": "GENRE_ELECTRONIC",
    "trip-hop": "GENRE_ELECTRONIC",
    "trip hop": "GENRE_ELECTRONIC",
    "downtempo": "GENRE_ELECTRONIC",
    "minimal": "GENRE_ELECTRONIC",
    "glitch": "GENRE_ELECTRONIC",
    "experimental": "GENRE_ELECTRONIC",

    # Hip-hop
    "hip-hop": "GENRE_HIP_HOP",
    "hip hop": "GENRE_HIP_HOP",
    "hiphop": "GENRE_HIP_HOP",
    "rap": "GENRE_HIP_HOP",
    "pop rap": "GENRE_HIP_HOP",
    "gangsta rap": "GENRE_HIP_HOP",
    "conscious rap": "GENRE_HIP_HOP",
    "conscious hip hop": "GENRE_HIP_HOP",
    "chill rap": "GENRE_HIP_HOP",
    "trap": "GENRE_HIP_HOP",

    # R&B / Soul
    "rnb": "GENRE_R&B_SOUL",
    "r&b": "GENRE_R&B_SOUL",
    "r-n-b": "GENRE_R&B_SOUL",
    "rhythm and blues": "GENRE_R&B_SOUL",
    "soul": "GENRE_R&B_SOUL",
    "neo-soul": "GENRE_R&B_SOUL",
    "funk": "GENRE_R&B_SOUL",
    "motown": "GENRE_R&B_SOUL",
    "disco": "GENRE_R&B_SOUL",
    "gospel": "GENRE_R&B_SOUL",
    "christian": "GENRE_R&B_SOUL",

    # Jazz
    "jazz": "GENRE_JAZZ",
    "smooth jazz": "GENRE_JAZZ",
    "bebop": "GENRE_JAZZ",
    "free jazz": "GENRE_JAZZ",
    "jazz fusion": "GENRE_JAZZ",
    "swing": "GENRE_JAZZ",
    "big band": "GENRE_JAZZ",
    "bossa nova": "GENRE_JAZZ",

    # Classical
    "classical": "GENRE_CLASSICAL",
    "orchestra": "GENRE_CLASSICAL",
    "symphony": "GENRE_CLASSICAL",
    "opera": "GENRE_CLASSICAL",
    "baroque": "GENRE_CLASSICAL",
    "chamber music": "GENRE_CLASSICAL",

    # Country
    "country": "GENRE_COUNTRY",
    "country rock": "GENRE_COUNTRY",
    "bluegrass": "GENRE_COUNTRY",
    "americana": "GENRE_COUNTRY",
    "country pop": "GENRE_COUNTRY",
    "alt-country": "GENRE_COUNTRY",

    # Blues
    "blues": "GENRE_BLUES",
    "blues rock": "GENRE_BLUES",
    "delta blues": "GENRE_BLUES",
    "electric blues": "GENRE_BLUES",

    # Reggae
    "reggae": "GENRE_REGGAE",
    "ska": "GENRE_REGGAE",
    "dub": "GENRE_REGGAE",
    "dancehall": "GENRE_REGGAE",
    "reggaeton": "GENRE_REGGAE",

    # Latin
    "latin": "GENRE_LATIN",
    "salsa": "GENRE_LATIN",
    "samba": "GENRE_LATIN",
    "cumbia": "GENRE_LATIN",
    "tango": "GENRE_LATIN",
    "latin pop": "GENRE_LATIN",

    # World
    "world": "GENRE_WORLD",
    "world music": "GENRE_WORLD",
    "african": "GENRE_WORLD",
    "celtic": "GENRE_WORLD",
    "french": "GENRE_WORLD",
    "italian": "GENRE_WORLD",
    "spanish": "GENRE_WORLD",
    "german": "GENRE_WORLD",
    "finnish": "GENRE_WORLD",

    # Soundtrack
    "soundtrack": "GENRE_SOUNDTRACK",
    "film score": "GENRE_SOUNDTRACK",
    "video game music": "GENRE_SOUNDTRACK",

    # Easy listening
    "easy listening": "GENRE_EASY_LISTENING",
    "lounge": "GENRE_EASY_LISTENING",
    "new age": "GENRE_EASY_LISTENING",

    # Ambient
    "ambient": "GENRE_AMBIENT",
    "chillout": "GENRE_AMBIENT",
    "meditation": "GENRE_AMBIENT",
    "drone": "GENRE_AMBIENT",

    # Folk
    "folk": "GENRE_FOLK",
    "folk rock": "GENRE_FOLK",
    "indie folk": "GENRE_FOLK",
    "singer-songwriter": "GENRE_FOLK",
    "acoustic": "GENRE_FOLK",
}

# Many-to-one mapping: Last.fm tag string -> tokenizer mood token
LASTFM_MOOD_MAP: dict[str, str] = {
    "happy": "MOOD_HAPPY",
    "fun": "MOOD_HAPPY",
    "feel good": "MOOD_HAPPY",
    "cheerful": "MOOD_HAPPY",
    "joyful": "MOOD_HAPPY",
    "makes me happy": "MOOD_HAPPY",
    "party": "MOOD_HAPPY",

    "sad": "MOOD_SAD",
    "depressing": "MOOD_SAD",
    "heartbreak": "MOOD_SAD",

    "energetic": "MOOD_ENERGETIC",
    "aggressive": "MOOD_ENERGETIC",
    "power": "MOOD_ENERGETIC",

    "calm": "MOOD_CALM",
    "relaxing": "MOOD_CALM",
    "peaceful": "MOOD_CALM",
    "chill": "MOOD_CALM",
    "soothing": "MOOD_CALM",
    "mellow": "MOOD_CALM",

    "dark": "MOOD_DARK",
    "evil": "MOOD_DARK",
    "sinister": "MOOD_DARK",
    "gothic": "MOOD_DARK",
    "haunting": "MOOD_DARK",

    "uplifting": "MOOD_UPLIFTING",
    "inspiring": "MOOD_UPLIFTING",
    "hope": "MOOD_UPLIFTING",
    "triumphant": "MOOD_UPLIFTING",

    "melancholy": "MOOD_MELANCHOLIC",
    "melancholic": "MOOD_MELANCHOLIC",
    "bittersweet": "MOOD_MELANCHOLIC",
    "nostalgic": "MOOD_MELANCHOLIC",

    "intense": "MOOD_INTENSE",
    "epic": "MOOD_INTENSE",
    "anthemic": "MOOD_INTENSE",
    "angry": "MOOD_INTENSE",
}


def map_lastfm_tags(all_tags_csv: str) -> dict[str, list[str]]:
    """
    Map comma-separated Last.fm tags to tokenizer tag categories.

    Preserves Last.fm ordering (most popular first) and deduplicates.

    Args:
        all_tags_csv: e.g. "hip-hop,rap,hip hop,rnb,pop"

    Returns:
        {"genres": ["GENRE_HIP_HOP", "GENRE_R&B_SOUL", "GENRE_POP"],
         "moods": ["MOOD_HAPPY"]}
    """
    if not all_tags_csv:
        return {"genres": [], "moods": []}

    tags = [t.strip().lower() for t in all_tags_csv.split(",") if t.strip()]

    genres = []
    moods = []
    seen_genres: set[str] = set()
    seen_moods: set[str] = set()

    for tag in tags:
        if tag in LASTFM_GENRE_MAP:
            genre_token = LASTFM_GENRE_MAP[tag]
            if genre_token not in seen_genres:
                genres.append(genre_token)
                seen_genres.add(genre_token)

        if tag in LASTFM_MOOD_MAP:
            mood_token = LASTFM_MOOD_MAP[tag]
            if mood_token not in seen_moods:
                moods.append(mood_token)
                seen_moods.add(mood_token)

    return {"genres": genres, "moods": moods}
