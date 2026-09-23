"""Validate author-supplied standard images and reuse archived ordinary ciphertexts.

No secret keys or plaintext standard images are distributed by this package.
"""
from pathlib import Path
import argparse, hashlib, json, shutil
import numpy as np
from PIL import Image

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--images',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[3]
    args.output.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((root/'results/reference/input_manifest.json').read_text(encoding='utf-8'))
    cipher_manifest=json.loads((Path(__file__).parent/'inputs/cipher_manifest.json').read_text(encoding='utf-8'))
    for r in manifest['images']:
        a=np.asarray(Image.open(args.images/r['source_filename']))
        assert a.dtype==np.uint8 and a.shape==(512,512),r['label']
        assert hashlib.sha256(a.tobytes(order='F')).hexdigest()==r['decoded_pixels_sha256'],r['label']
        Image.fromarray(a).save(args.output/(r['label']+'_plaintext.png'))
        f=Path(__file__).parent/'inputs'/(r['label']+'_ciphertext.png')
        assert hashlib.sha256(f.read_bytes()).hexdigest()==cipher_manifest[r['label']]['file_sha256']
        shutil.copy2(f,args.output/f.name)
    print('Four validated plaintext/archived AES ciphertext pairs prepared; no keys exported.')
if __name__=='__main__':main()
