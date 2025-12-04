#!/usr/bin/env python3
from typing import List
from cryptography.hazmat.primitives import serialization
import json, base64
import jwt, datetime
import requests

KID = '1234'


def curveConvert(source: int) -> str:
    # 1. Convert to raw bytes with big-endian encoding
    # 2. Because numbers are large, we have to specify the number of bytes. We pick the shortest length using this math and align to full bytes.
    # 3. Encode to base64 and remove '=' padding.
    return (
        base64.urlsafe_b64encode(source.to_bytes((source.bit_length() + 7) // 8, 'big'))
        .decode('utf-8')
        .rstrip('=')
    )


def getJWKsUri(issuer: str) -> str:
    # Fetch OIDC discovery document
    resp = requests.get(f"{issuer}/.well-known/openid-configuration")
    resp.raise_for_status()
    return resp.json()['jwks_uri']


def getJWKs(jwks_uri: str) -> dict:
    resp = requests.get(jwks_uri)
    resp.raise_for_status()
    return resp.json()


def createJWK(key_path: str):
    with open(key_path, 'rb') as key_file:
        pub = serialization.load_pem_public_key(key_file.read())

    # Extract modulus and exponent
    modulus = pub.public_numbers().n
    exponent = pub.public_numbers().e

    modulus = curveConvert(modulus)
    exponent = curveConvert(exponent)

    # Format as proper JWK JSON
    keys = {
        'keys': [
            {
                'kty': 'RSA',
                'alg': 'RS256',
                'use': 'sig',
                'n': modulus,
                'e': exponent,
                'kid': KID,
            }
        ]
    }

    with open(key_path + '.jwk.json', 'w') as json_file:
        json.dump(keys, json_file)


def createJWT(key_path: str, iss: str, sub: str, aud: str, lifetime=600) -> str:
    # These three things must be correct. Match the issuer to your website.

    iat = datetime.datetime.now(datetime.timezone.utc)
    exp = iat + datetime.timedelta(seconds=lifetime)

    with open(key_path, 'rb') as key_file:
        private_key = key_file.read()

    # Creating JWT
    token = jwt.encode(
        {'sub': sub, 'aud': aud, 'iss': iss, 'iat': iat, 'exp': exp},
        private_key,
        algorithm='RS256',
        headers={'kid': KID},
    )

    print(token)  # Print to stdout
    return token


def verifyToken(
    token: str,
    jwks: dict,
    audience: str,
    issuer: str,
    algorithms: List[str] = ['RS256', 'ES384'],
) -> dict:
    # The jose library can handle JWKS keys directly
    try:
        claims = jwt.decode(
            token, jwks, algorithms=algorithms, audience=audience, issuer=issuer
        )
        return claims
    except Exception as e:
        print('Token verification failed:', e)
        return None


if __name__ == '__main__':
    # Specify the path to the private key
    issuer = 'https://example.com'
    key_path_pvt = 'pki-hegerdes/ca.key'
    key_path_pub = 'pki-hegerdes/ca-public-key.pem'
    iss = 'https://oidc.mydomain.com'
    sub = 'test-subject-user'
    aud = 'my-client-id'
    createJWK(key_path_pub)
    token = createJWT(key_path_pvt, iss, sub, aud)
    verifyToken(token, getJWKs(getJWKsUri(issuer))['keys'][0], aud, issuer)
    print(token)
