// Mock courier API for the challenge. Run: node courier-server.js [port] [--real]
// Node 18 or newer, no packages. Data lives in memory: restart to reset.
// Without --real it is the calm system that courier-api-notes.md describes (Step 1). With --real it behaves like the live platform on a busy day (Step 2).
//
// The mock itself is packed below so that this file does not read like a list of what the live system does: you find
// that out by using it, as you would with the real platform. It is ordinary JavaScript, and it can load only these
// Node modules: http. If you prefer not to run code you have not read, run it in a container: it needs nothing but Node.
const ALLOWED = ["http"]
const load = (m) => { if (!ALLOWED.includes(m)) throw new Error(m + ' is not available to the mock'); return require(m) }
const PACKED = [
  'eNq9nG1z2ziSx9/7UyCsvVDcyAwAEnyq06TyNMns5KkST23dZbJTsAhb3FCkB6Ts0Wb83a8AUhIkNeVEyFxepCQ2CAJ/Nhu/htqc1lXTolnbXqEJkuL3RSHF',
  'yFXfXe/kZKqt796+P0MT9GYxPxdydCXrqWgan8vLa/+iqPLRiHto8gN6+K9f8wd/e+i3omlH3PM89OefKMQY9928f/74FZqgrfOLalouctGM3NNTKXjpen3j',
  's7c/P3+DJsid1gtZCHmai3l92tafReX2TZ49PnuMJujjF6fInYyMnemiaeu5kG/4XDiZ87gspgK9/cwvaumMnatZXanDD8IwVqPS/5yxM+Xl/N2Ajee5FE3j',
  'ZF+csqgEcTKHUPSaS4E+tFKIVrWRgjuZ85JPP1di6Yydklf5nMvPTuaclwuB8rqWY8TP62uB2plA51yeC+ncjp2iFfNGD53P60XVOlmIx84VX85F1b6uczWk',
  'KW9mzthpWt4uGidzclEW10KK3Bk7OV86GR47baEnjJNMj/o/dSVyJ2vlQoyd6YxXlSidzLkR503RCjXkpikuK6HOWdYL53bcSUj3JHwiKvR6Ia9myz0B44AR',
  'QgNQwI0NEpCh90uBXvFKbNR7xsumrStDFLoRJY59ZiNLmpHAQpZgT5ans7IW6JdmzqtdXUgYY0rDCNLFsEG6JOjpjJef0Y9cztH7mucbed6J6ecZnxvyBBt5',
  'CAn9dFefK17kX6kPwRmNLPQJ9/R5Jq7Ry8XlTDQbeapFWQKaUIpZEEQprAkl6Gld5jMuz+uF3PGZJ7L4Y9tnQkMURvw0tfAaQrIgtVCF7anyXBYV+sCrtm52',
  'vYamIQ7DlEJeY9gghUL0st6PRk/5PBeVZTAiSeLTO5+8etEC6tGMUQv1oj31fuSSz9ATUVWibXf1C6KYsYgwSD/DBukXw+H8Qyt5e1HLHA5JdF+X3Seunxnk',
  'WkGGmYU48Z44L0QtLwV6U1/zz7vahCHBURwkkDaGDdAmwECk/icv2xmfN219A4cjGtG7w/UBccKMJBbiJHvivOQVR/+UxeVsz28YCVmcRATSxrBB2gTD0fqJ',
  'kPO6yhuxhGMTTVM/tVCIZQGxUCjdU+inueQV+nm2v5yxJMFJmoSgQBsbJFB0IHR/H1iKIyDEf8NjGGVhaKEjwXtC/kM0DTrjy3KfOKOIRJjgGFLSsEFKpmCI',
  'P4hMhARfEbqHtcFJxmIbbfZx/OcbPhfoHW9FuatNz4sgjRs2QJtwgMYPAxPDFsqkGbGBbLJP2a9ExdF7of12S5cEJxENGAjZhg3SBYLsw8CUAJT9DQ8TzqgN',
  'ZJN9yn5dDyRvSUJJEMYgYxs2SJYDjP1dkInS0Cq0kyywQXGyz+JvCj6QwqWMRSFLU0hGwwbIyA5h+V3kFH0NmB+QiGbht3J53c70DetF2kfzt82Uy92EDs5Y',
  'GKYpYTEd4HEG8/jd1JRCrP1tTGkD3CQa2D/ZzeM6EQimUZSEEHCbNkigAeC+C5piS6a0AW4SgzsjYC7HSByROI0SUJqNDZAmgnj7+6ASIXZQzjJqA+UkGdhD',
  'gfM5RsM0SnEKcblpgzQ8wOWHiSlMfUuYtIFykoK7KFBGxwIaUEwJBOWmDVLnEJQfZqYksgrbCihtYJtieD8FzOtYkEYxCYIYVGhjgxSCYfsgOlFqCdtphm1g',
  'm5KB3RIgo2P9HiTE2qYNkCYeYO3vA04RtoNPq41vOrSjAuZyjIVBHLAE4nLTBmkIcfldxJTGVrGbZIENmdMA3lGBMjkWkZiGMYbQ3LRByhxA8zvpKbajbpqF',
  'NtRNw4EdFSCnY1GKY5bQFFRoYwMUSg5uht+BT4QQu82SIGM22+GUwZslYIbH4iikUcqg/XDTBokE8/d3oqgwsQr0ikNtIJ1GA7squwneQOqSBHGc4HiAzJMB',
  'Mj+MTYklVjKrXI7G8G4K9NscSwmhKUlBMjdsgDQpROYHeYlSarWdEmWBDXDTBNpOgXO5NAkTHFAQtg0bJMuhTfCDxMSsdsAVTNrANk3BbRIwn4swSwIShhBt',
  'mzZInkO0/X2oKbWk8jTDNlQe4IGtFDivi0hAEsoiiMtNG6QlzOV3oFMc2G2q4IzYgHkwVJQCpXVR/0s4ROamDSodwANofic4OYRgXxeN2OClwd4XvGy2RCqq',
  'puWXks8PyAQXnoCpXUTjJAkTEoAqbWygSuCm+B3g5JAw9pmVQjQLA0uFhmpQgAwvChgNWBpADG7aQIUOQPh3Qqgk9C0x1AbVA7hYBUzzopCyJMYMQnXTBglJ',
  'DrH6QaByKFWk7lhRJk4t/W2gegXK+aIwTYOEJBSUaWMDZYJp/SBZOZQpCnfssJNaCjRUoAKkfBGLaZIGGNosN22gQEO75QfpKrUkT5u98mCwOmU31YOTlCgK',
  'oxCHNBkqv4RQ/LvAlBNTu0CPkyxMLP1qoHwF/AUvikmaEsYgcjdtoIwH0P0OqHIITv3USqg0w8RSqKEqFijzi+I0CGkUgwxv2EChDkH8nXxFQssaFZwRG0AP',
  'B2pUwEwwSqIoDeIUxHPDBso0sG9+J10lgWUwJxmN7XwpHCpWgRPCvh4T5HTDBqkU/KXF4w6ltjBPs9AS5sOB+hY4I4wxCdIIhxDOmzZQzG8uJKfMrsYlyJjN',
  'TnoI1rhAuWCMkziMSRSBsmxsoCzH1pE7NA3t4roiz8jSfeAKFjAXjEmE04QmEKCbNkil8OjKcie25XOWEUs+D4dKWIB8MKZBGKYhgfjctIEq/ZXV5diy4iXK',
  'ApvN9HCo4gVMBuMAJxizAIJ40waqeFyNuUNCZhfOFZAyS0+DS1+gRDAOEsJIxBJQoo0N/Jugo0rNHZLYInuaMUtkD4dqW7ZTQTjbiUPGMI2TIUxnNmXmxK6i',
  'BWfEZpM9hCtawB/8YkYTFqQYAnTTBkr01xeaO5RFljGfZDS08zM2UAEDpoZxhClWngUJathAQY+oN3doehTHnxKTPQNLkGdDhTBQUhj3fxeEQYk2Nkii6Jiy',
  '8/ibK1xMdYKM2ZS4sMESFzAVjOMwxTGNQS43bKA431x77hB81B67qU+YYctNdjZQ6AJmgXFCKUuCFCR0wwYK9FdXoStwO4bkTT1ZRixRng2VxQykgkka4ZQR',
  'kOYNG6RobFGQTpJjKmNMqaKMWv2l6EBpDJgYplEa4SgEYd6wgSIdWZruUHLUhjvZ4lDLDXc2VPoCZoYJDgNC4giiddMGynRkgbpD2VG4TrZg1BLX2UA9DJAX',
  'JoREEU0SCNdNG/in6n9dpTpNjyicISa1YpvCGQYWzoApYUJSTEJMCCjgxgYKeGyZuhN91d77BS9KUB6SUcuddwYXz+xkhHC6k9AoiBgJhlg+Obo+3SH4KETf',
  '5k9LRI+GymGAXwWTIIhJRBlE6KYNlOmIInUSHlMLswWg4VG1MJ9Wr5G54jmaoFGlXxbzoZVFdTmqPP+K5x9aLtsRHSMXu97JxaKatkVdoabl86tRzpdjpAYx',
  'RvraHvpyglDXpeqwEjfoGW/FyDtBKPcb0f5y9lQfyP3LzRcPPUA5X3rrc895I9AErRr9uCjL/xFc6obuqYseqAGv+3hdV+1M2wjcoLuItp0pmxqx+pJh7J4g',
  'JEW7kFU3A/Sou/gD5P6vizL95eR2JZOsbxo00W+38ef8ajSSWrCRmnWRZ0j6RT5WszAcTR01vyu7drase+vOIyR9/R3plit3U816/1LH+4/qqPYffS31QbfT',
  'fmT01x1A2eq9QKsjXjc4KUU1XWbIffHknavHs3E81bHxVVk7DzS67w7o8fYfJ5MJcrvA5qJHyF35qms00l1NZyJflCJ/vBlu50rS184k/c6dpN87VNbb8cam',
  '/LubSefiWrfu4/jk1lu9pqi+qYTsnfA1vxrt3rWP+m4ZovUPB8qQu6wX7qd1T5/FsjE6Wh1uZSHU8S+3/YEbXrTqMZo3+gKq/TtZz4tGjEZSNHV5LbShEe1Z',
  'MRf1ol0dHqN5s77claimyv1H17r1a97OfFkvqnzU385rD/0dEYy9E+OBFFWuehv3t2uMzut8OUYzwXMhm+7JlKLxb2TRipeC56NVw7fn/xbTtp//6It6r1PV',
  'iqo9bZdXws2Qy6+uymLK1XUe/rupK3eMXD5Vb4o6VU1lXZ7ysqxvTmtZXBaVOuXvLrrdXNzrr63G+I8Pb9/4jQ4xxcVypEbpeeoRW09FCp4/qfPlSIrfV+PW',
  'T+igoKoNQqVokeQ36s1Urj4gxe9+XY3cnLfcHaPRtGusGz2YoCm69bbaiSpXzYwuEWrlUp3RXWykznyE9BSuuGz0AeWjX249dIumvJ3O0Eh4xhlqsfXQre5N',
  'X+5WT1a9xcufSsFb8UHIayFHvFlWU6TmPFYnrwfR+cRClr0H/vL+lWrkL2Q5RvptYNnDh2U95eWsblpXXaK40P34c9HO6rx7ON++O/vp7ZsPrtfPbNsVKA7H',
  '6MtX3NWhO9/fae0ti3ZWy+I/2l/GyHSmMSpyMb+qWxV/Tj+L5WB/3dB1fy+en43Ru7cfztzN/dLusPIoraox7X4s/tZA0D2lwhPBpZBILQL6LWbeqq/N4xNi',
  'oqSY6ljoLqpVLyqY3XonA/K+eH7movv31X3yr3g7q1T+oy0P+xcZFaJZi891pFD/jfrwE2GMMkTVM60adDd9FVx1r43gcjp7xyWfN2pdG7md2TXP4Betjnl9',
  'oIDP041c/Qq4rcuVxVzHLx1w5kU16j7wP0YHu9Onud0r5SgeI+KNEWXbHTeqX7V6+hdF2Qq5isEqBKMf+mHfv49G9/o5//nn9uLSffTMXvXyhya6d79RPw+p',
  'RUKPxmxWiT/aVatSVJftDP3QT/VR18dH/f/KeIrIJzWqDKlH1/S3jY9QjJWPdAtwd4Xu2T7Z4I9oeVH2927lEf5cRYjRw3/9anjFrw9Hv+YPvL899O7wra7L',
  'lQ/1IuSbu93ZP5JP5vRlfbORXr0Q0BBe9V7kXWt14XuyvgGfiNB4Iqq6/e1CrUbrx1Gdqt34/n3U90qoZzo5Ve/s2/LTDlDWQ5f1zQpRDii+s1DdjtW81NC6',
  'U8dIZRTPFoph6huTYjodFVArOlFP2uqMqm5Fk6lh/xdiuhlW/PKCt0JPGIUhiX30SvBrgW6KdqaT5GldTQuhdmiLC1TVag1DvGpuVNRRyOMqbXYcYlrPr0rR',
  'im9wiV8frk4ado4uMN6/v+5/2D9WLf7/PWSNUd2LLFcR+qO7uxx8Wl9JNb5/X6OXP+ON+u5561W5j4/8Wqj56UYqFqlGfYu9MerGKxTtv2n46JZmY5z6dk56',
  '/92CkfXouiaTCeqW931BKDUEKaprXhaKLeaiafilOnam9lpUL0WjnBDpFh1ZrNaZ/obXN1uUvX4vngveiNS4Li/V6Je/bU4Zo/VnReCqb+OAirpqQuaDrSla',
  'i1vkXreIKji+89pSrHOA7WkXzWoMS1TVN+hclHV12aC2RrzSf0GG+veK7gihQoxncFkhmo9F/kmB8uaLXtNUJtg3Uyf2fhwrf9q0/O8JosAsGA62l/9rXpT8',
  'vBRrZ97qlOLtXnXwAx3CFKcp65vf8vqm0pT8RanVyuVptzBnyA3WF7vdzF8BVH2hncZXge5pXZZi2oq8uyuVfshdpcC9EdDohwnC3je46kUhyjxD7lYvO0+0',
  '+OOq63xyd8QdiPRqZjrhAcbc+VtnXV3q7imoLn6bF40OrO54M8iVM/VhT0xFca3d3tyo8Nv6pw9v+y0Qc67mczJB5s3Ysqhpd9mNjsr3umn7RfOGvxmpS/SJ',
  'w+6Znqe2Hna7y4xhdgujEQ3MWLA2bg/T+GZMpV4o2xek0t9Vcu8OBImxKdStGZ69Lu42XdxVN2DVl16s1VwyfalhTAiCbUxga0yAAaBetOtV9ZsWoVvPVwAo',
  'qpF6YfIqx1Nq1KXwy/py5L6up59XkQc9fvcTqiu0m11lKnHQr1x+gFbk7qo1mZdoXufC04s/GqldnP6A53kn/wexnp9S',
].join('')
const code = require('zlib').inflateSync(Buffer.from(PACKED, 'base64')).toString('utf8')
new Function('require', 'process', code + '\n//# sourceURL=courier-server.js')(load, process)
