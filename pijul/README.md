I really like the idea of a source versioning tool called pijul.

It has a few good features like managing conflicts better, and only tracking patches.

This sounds really good in theory, and i like the idea so i have spent a few years on and off using it, recently i decided to learn alot more about it, and even understand how it works.

Im not an expert but i understand enoug to say a few things about it.

When i initaly looked at pijul i thought WOW this will be smaller and better than git, and everyone will use it. Git will probably add the feature to git and then that will be all.

Now several years later that has not happened, and learning more about it i now feel like i know why?

reading about pijul and reading the source code i find that the diffs are stored in a file, named with the diff hash in a folder called `changes` in this folder the first 2 letters of a hash will be used to name a folder, and then the changes are small files in each folder.

To me this is a little bit of a worrying sign, each patch is a file... so there will be alot of small files, each file will probably eat one block on a disk meaning that a 500 byte file will eat atleast 512,1024 or 4096 bytes. 

Im on an ssd so in my case its 4096, this means that each file is if i have 30 changes to 1 file this will create 30 small patch files each of them with eating atleast 4096 bytes of physical disk space. 


doing som bistro math we can say this.

lets say the file was 8192 in size thats 2 blocks of 4096 bytes consumed by 1 file, and we have 30 changes to this file. 

lets say it started at 2048 bytes and over the course of these edits it grew to 8192 bytes, this is a large text file, there are bigger but this is alot of text.

if each change is about 205 bytes or 205 characters, we will have 30 files 205 byte each, but that is not quite true. pijul uses zstd to compress them, infact it uses [zstd seekable](https://github.com/facebook/zstd/blob/dev/contrib/seekable_format/zstd_seekable_compression_format.md) meaning that it will have seek frames etc inside adding a little extra space, this space is miniscule compared to the space each individual file will consume on the hardrive.

if each file was 205 bytes, 30 of them would consume 6150 bytes. But each file will consume a 4k block on the disk making the final size 122 880 bytes or 120MiB vs 6MiB of the accutal changes.


But this is just speculation right? I know nothing, so i needed to test it.

My initial idea was to use my own repo with many commits [Skabunkel/banned-ip-addresses](https://github.com/Skabunkel/banned-ip-addresses) but that is an extream case of what real changes would look like, it was a cronjob running on my VPS recording the IP addresses banned by fail2ban for several months. it is 1 or 2 line changes at most.

I need something better.

First i wanted to try the linux source code, but that would be a little too big to do a first test with, then i looked at NixOS/nixpkgs but that is also a bit too big. So i asked AI for a suggestion that would be alot of small files being changed.

it suggested [facebook/react](https://github.com/facebook/react) 

And that looks perfect, only 21k commits and alot of tiny files. Pluss its 946MiB or about 1GB in size so it was a big chunky repo.

Then came how should i migrate the data, well there is a `--git` flag that you can add to pijul but that has failed before and i wanted it to behave like they had started using pijul, so i wrote a dumb script to migrate it. this script is in [commit.sh](https://github.com/Skabunkel/public-notes/pijul/commit.sh).

This script will take a file that is a long list of commits and apply thiem one after the other and record the state in pijul.

To create the hash file i used this command.
```
git log --reverse --pretty=format:"%H" > commits.txt
```
Initially i ran the script and was happy, but when i saw the result `i thought that cant be right` and realized i forgot to add `.git` to `.ignore` so i decided i would cheat a little by copying the current version of the .gitignore file into the .ignore file aswell.

```
cat .gitignore > .ignore
echo '.git' >> .ignore
```
running the script via `./commit.sh commits.txt` it will go through each line and... well its still running and the `.pijul` folder is almost up to 11k files and 1,9GiB the .git folder is 946MiB with only 28 files not 28k files 28.

Stats bellow

| folder | files  | folders | size      | Size bytes    |
|--------|--------|---------|-----------|---------------|
| .git   | 28     | 15      | 946.2 MiB | 992 162 854   |
| .pijul | 11 361 | 1 027   | 2.0 GiB   | 2 094 365 715 |

I cancelled at commit 848327760f4d351e41f75385709c7748cfff9164 from Aug 13, 2019

Ironically when A "Brian Vaughn" committed "Initializing empty merge repo" that cleared out all files.


I really want to like pijul i has a few good ideas, but one file per diff does not scale. 
Ill see if i can spend some time cleaning up the code and add my own storage back end. 

Im currently struggling with understanding `sanakirja` which is the database pijul uses for channels(branches).

I have a few ideas. 
1 would be have an archive per file, it would be more than gits impressive 28 files for a repo that has way more than 28 files.

There is also the fact that zstd has support for creating optemized dictionaries before compressing data (google `zstd --train`) and maybe i can use that.

// N.Au 
Ps. I should have gone to bed about 1 hour ago <_< why do i do this to myself.