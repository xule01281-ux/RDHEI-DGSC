function h=paper_sha256(bytes)
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(uint8(bytes(:)),'int8'));
b=typecast(digest.digest(),'uint8');h=lower(reshape(dec2hex(b,2).',1,[]));
end
