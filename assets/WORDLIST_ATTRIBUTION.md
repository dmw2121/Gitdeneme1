# Turkish word list attribution

The words in `words_tr.json` are a filtered subset of the Turkish `small_tr`
frequency data from [wordfreq](https://github.com/rspeer/wordfreq), maintained
by Robyn Speer. Source revision:

- Commit: `912caf64b657478d1dff1138efdc078947d54bb1`
- Source file: `wordfreq/data/small_tr.msgpack.gz`
- Source file SHA-1 (Git blob): `9264ad4978a7b06b3df8b08617c1dbd6799068b2`

The selection keeps the 1,000 most frequent distinct lowercase entries for
each length from four through seven, restricted to the 29 letters of the
Turkish alphabet. The source has more than 1,000 eligible entries at each
length. The resulting word list is an adaptation of the source frequency data
and is licensed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

The upstream data attribution and licensing notes are retained in
`../licenses/wordfreq-NOTICE.md`; the upstream code license is retained in
`../licenses/wordfreq-LICENSE.txt`. No wordfreq software code is included in
this app. For the complete CC BY-SA 4.0 legal terms, see the linked license.
