const METADATA = [
  { id: 0 },
  { id: 1 },
  { id: 2 },
  { id: 3 },
  { id: 4 },
  { id: 5 },
  { id: 6 },
  { id: 7 },
  { id: 8 },
  { id: 9 }
]

/**
 * Offsets metadata array according to a random seed value.
 *
 * metadata[id] => metadata[(id + seed) % metadata.length]
 *
 * @param   {Array}  metadata Original array of metadata objects.
 * @param   {Number} seed     Random seed.
 * @returns {Array}           Metadata array offset as function of random seed.
 */
function offsetMetadata(metadata, seed) {
  return metadata.map((_, index) => metadata[(index + seed) % metadata.length])
}

console.log(offsetMetadata(METADATA, 720823774))
