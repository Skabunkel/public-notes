# Notes on pijul

I really like the *idea* of a source versioning tool called pijul.

It has a few good features better conflict handling, and patch-based tracking instead of snapshots. That sounds great in theory, and I liked the idea enough that I've spent a few years on and off using it. Recently I decided to learn a lot more about it, and even understand how it works.

I'm not an expert, but I understand enough to say a few things about it.

When I initially looked at pijul I thought *wow, this will be smaller and better than git, and everyone will use it. Git will probably copy the feature, and that will be that.*

Now, several years later, that hasn't happened and after digging into it, I think I know why.

## How pijul stores changes

Reading about pijul and reading the source code, I found that diffs are stored one-per-file, named by the diff hash, in a folder called `changes`. Inside that folder, the first 2 letters of a hash name a sub-folder, and the changes are small files in each sub-folder.

To me this is a worrying sign. Each patch is its own file, so there will be a lot of small files and each file eats one block on disk. A 500-byte file will consume at least 512, 1024, or 4096 bytes depending on the filesystem.

I'm on an SSD, so in my case it's 4096. That means if I have 30 changes to one file, I'll have 30 small patch files, each consuming at least 4096 bytes of physical disk space.

## Some bistro math

Let's say a file is 8192 bytes that's 2 blocks of 4096 bytes consumed by 1 file and we have 30 changes to it. Let's say it started at 2048 bytes and grew to 8192 bytes over those edits. That's a large text file; there are bigger, but it's a lot of text.

If each change is about 205 bytes (or 205 characters), 30 of them would be 6150 bytes of actual content. Pijul also uses [zstd seekable](https://github.com/facebook/zstd/blob/dev/contrib/seekable_format/zstd_seekable_compression_format.md) compression, which adds seek frames and a little overhead minuscule compared to the per-file block waste.

So the *content* is around 6 KiB. But each file claims a full 4 KiB block on disk, making the on-disk footprint **122,880 bytes (~120 KiB)** vs. ~6 KiB of actual data.

## Speculation isn't enough let's test

But this is just speculation, right? I needed to test it.

My initial idea was to use my own repo with many commits [Skabunkel/banned-ip-addresses](https://github.com/Skabunkel/banned-ip-addresses) but that's an extreme case. It was a cron job on my VPS recording IP addresses banned by fail2ban over several months: 1- or 2-line changes at most. I needed something more representative.

First I considered the Linux source code, but that felt too big for a first test. NixOS/nixpkgs was also too big. So I asked an AI for a suggestion that would have a lot of small files being changed, and it suggested [facebook/react](https://github.com/facebook/react).

That looked perfect: only 21k commits, lots of tiny files, and at 946 MiB (~1 GB) it's a chunky repo.

## Migrating the data

Then came the question of how to migrate. There's a `--git` flag you can pass to pijul, but it has failed for me before and I wanted the result to behave as if the project had started using pijul from day one. So I wrote a dumb script: [commit.sh](https://github.com/Skabunkel/public-notes/blob/main/pijul/commit.sh).

The script takes a file containing a long list of commit hashes and applies them one after the other, recording the state in pijul.

To create the hash file:

```
❯ git log --reverse --pretty=format:"%H" > commits.txt
```

I ran the script, was happy at first, and then thought *that can't be right* when I saw the result I'd forgotten to add `.git` to `.ignore`. So I cheated a little by copying the current `.gitignore` into `.ignore`:

```
❯ cat .gitignore > .ignore
❯ echo '.git' >> .ignore
```

Running `./commit.sh commits.txt`, the script chewed through commits one at a time. It's still running, and the `.pijul` folder is already up to 11k files and 1.9 GiB. The `.git` folder, by comparison, is 946 MiB with **28 files**. Not 28k. Twenty-eight.

## Results

| folder | files  | folders | size      | size (bytes)  |
|--------|--------|---------|-----------|---------------|
| .git   | 28     | 15      | 946.2 MiB | 992 162 854   |
| .pijul | 11 361 | 1 027   | 2.0 GiB   | 2 094 365 715 |

I cancelled at commit `848327760f4d351e41f75385709c7748cfff9164` from Aug 13, 2019. Ironically, that's where "Brian Vaughn" committed *"Initializing empty merge repo"* which cleared out all the files.

*edit*

I realize i did not event look at my original point(and AI pointed it out), waisted space on disk.

```
# Size on disk
❯ du -s --block-size=1 .pijul/
2120962048      .pijul/
# Size it should be.
❯ du --apparent-size -s --block-size=1 .pijul/
2093044109      .pijul/
```

So the difference lost to the small file size is not as extreme as i expected, 2 120 962 048 vs 2 093 044 109 bytes.
A difference of about 27 917 939 bytes, or 26-ish MiB.

The major difference is probably that the patches are compressed sepperatly rather than together, loosing some of the benefits of zstd compression... A dumb test i could do is to compress change folder `.pijul/changes` with zstd --train and see if that improves the situation.

### Pijul gc tangent
 
```
zstd --train ./.pijul/changes/* -o changes
Error 12 : not enough memory for DiB_trainFiles
```
Hmm, the buffer is not enough i guess.

After some rubber ducking with an AI, decompressing everything and recomrpressing would be a better more fair test.

So 2 scripts later [extract.sh](https://github.com/Skabunkel/public-notes/blob/main/pijul/extract.sh) and [compress.sh](https://github.com/Skabunkel/public-notes/blob/main/pijul/compress.sh) and we have implemented a basic `pijul gc` feature... by not using pijul.

An important note, i had to reduce this to only 2000 commits and not all 11356 i want to finish this today.

```
#  Size on disk.
❯ du --apparent-size -s --block-size=1 /tmp/c_nodict /tmp/c_dict
279209941       /tmp/c_nodict
283599998       /tmp/c_dict
#  Size on disk with block waste.
❯ du  -s --block-size=1 /tmp/c_nodict /tmp/c_dict
284188672       /tmp/c_nodict
288964608       /tmp/c_dict
```

block waste here is less important, but this is 2000 diffs and they are 271MiB at their smallest. Im starting to think zstd is not the right tool for the job here? as a last ditch effort i tld zstd to compress all files and concatenate them, together 
```
❯ zstd -19 -r /tmp/pchanges -o pchanges.zst
```
zstd tell us that we will lose filenames and directory structure but this is just a way to guage a path forward, if we do this in code i think we can recover them somehow.

```
#  Size on disk.
❯ du --apparent-size -s --block-size=1 pchanges.zst
279209941       pchanges.zst
#  Size on disk with block waste.
❯ du -s --block-size=1 pchanges.zst
279212032       pchanges.zst
```
About 266MiB, and how would this compare to a git repository.... No clue... This became its own tangent.

But just running zstd compression on the files is way better than one by one it seems, and we have 2000 frames now, so we can address each file and recreate the directory structure by frame index.

However, if we assume that all patches are about the same size and compression is going to remain the same we still get 1,4 GiB in the end.

## Where I'd go from here

I really *want* to like pijul. It has good ideas. But one file per diff doesn't scale.

I'll see if I can spend some time poking at the code and adding my own storage backend. Right now I'm struggling to understand `sanakirja`, the database pijul uses for channels (branches).

A few ideas:

- One archive per file. That'd be more than git's impressive 28 files for a repo that has way more than 28 files, but still way fewer than 11k.
- zstd has support for training optimized dictionaries before compressing data (try `zstd --train`) maybe that helps too.

- Better testing setup.
    Create a repo from react with some commits.

- Try zstd --patch-form (THIS WILL TAKE FOREVER). i might write a program for this.


// N.Au

Ps. I should have gone to bed about an hour ago `<_<` why do I do this to myself.
