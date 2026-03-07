hypothesis:
1. Pageable memory with a single stream will serialize all operations.
2. Pinned memory will reduce transfer overhead but still serialize in a single stream.
3. Pinned memory with multiple streams and double buffering will allow partial overlap between copy and compute.
