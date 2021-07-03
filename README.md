
# OPUS Resource Repository Backend

A package based on the resource repository developed as part of the [LetsMT! project](http://project.letsmt.eu/). It has been updated and adjusted for modern GNU/Linux systems and improved in various ways. For historical reasons we will keep the name `LetsMT! Resource Repository` and the webservice will still use `<letsmt>` as its response root. Some of the changes are listed in [doc/Changes.md](doc/Changes.md).

More background and documentation is available in [doc/README.md](doc/README.md)


## System requirements

* One ("monolithic" installation) or several PCs (distributed installation) or (for testing) virtual machines.
* GNU/Linux operating system, tested on Ubuntu 20.04 LTS
* Perl 5.10 or higher
* Apache 2.x with ModPerl


## Installation

Standard (monolithic) installation on one machine:

```
git clone https://github.com/Helsinki-NLP/OPUS-repository.git
cd OPUS-repository
export HOSTNAME=<fully-qualified-domain-name>
sudo make install
```

The installation process will take quite some time and hopefully sets up all required software including a SLURM server, Apache Tika server and the repository backend webservice based on a secure REST-like API with self-signed certificates.

Test the installation by running:

```
make test
```

Additional tests can be run by using

```
make test-slow
```


## PACKAGE CONTENTS

```
admin/ ............. Scripts for administration
installation/ ...... Scripts & Makefiles for setup & installation
perllib/ ........... Perl modules and scripts
perllib/LetsMT/ .... LetsMT package of Perl modules & scripts
lib/ ............... Third-party packages/libraries
doc/ ............... markdown documentation
isa/ ............... interactive sentence aligner
ida/ ............... interactive dependency annotation
marianNMT .......... installation scripts for marianNMT

www/ ............... Extra: web interface (deprecated)
```


### Detailed contents for perllib/LetsMT/

```
  bin/ ....... essential scripts using/used by the LetsMT modules
  doc/ ....... documentation generated from source (perldoc)
  lib/ ....... all Perl modules
  share/ ..... other global files necessary for the Perl modules
  t/ ......... test scripts
  xt/ ........ "extra" test scripts (for developers only)
```

Detailed documentation is generated from the source code (make doc)
and more has still to be writen.


### perllib/LetsMT/lib/

The LetsMT package basically includes modules for several purposes:

* implementation of the repository web-service:
```
  LetsMT/Repository
  LetsMT/Repository/AdminManager ..... administrative functions
  LetsMT/Repository/GroupManager ..... access to group database
  LetsMT/Repository/JobManager   ..... access to SGE
  LetsMT/Repository/StorageManager ... access to the data repository
```
* an Application Program Interface (API) to the web service (REST calls)
```
  LetsMT/Repository/API/Access ....... calls to set group permissions
  LetsMT/Repository/API/Admin ........ admin calls
  LetsMT/Repository/API/Group ........ calls to group database
  LetsMT/Repository/API/Letsmt ....... obsolescent "high-level" calls storage
  LetsMT/Repository/API/MetaData ..... calls to metadata database
  LetsMT/Repository/API/Storage ...... calls to storage server
  LetsMT/WebService .................. entry point for talking to the API in Perl
```
* modules for data processing (I/O, conversion, ...)
```
  LetsMT/Align ....................... wrapper around various sentence aligners
  LetsMT/Align/GaleChurch
  LetsMT/Align/HunAlign
  LetsMT/Corpus ...................... reading/writing data in various formats
  LetsMT/Import ...................... convert/import data to LetsMT
  LetsMT/Import/PDF ...................... PDF files
  LetsMT/Import/DOC ...................... MS word documents
  LetsMT/Import/TXT ...................... plain text files
  LetsMT/Import/XML ...................... arbitrary xml files
  LetsMT/DataProcessing/Normalizer ... normalization
  LetsMT/DataProcessing/Splitter ..... sentence splitting
  LetsMT/DataProcessing/Tokenizer .... (de)tokenization (generic, language/specific ...)
```

### perllib/LetsMT/bin

Command-line tools:

* `letsmt_rest`: Command-line tool to perform common tasks via the LetsMT webservice API.
* `letsmt_fetch`: Fetch SMT training data (parallel and monolingual) from the repository according to the specifications in a configuration file.
* `letsmt_convert`: Convert between different file formats.
* `letsmt_import`: Validate/convert/import data files that have been uploaded to LetsMT. It can also be used to import OPUS corpora from command-line.
* `letsmt_tokenize` & `letsmt_detokenize`: Tokenize and de-tokenize a text.



## LICENSE

LetsMT! Resource Repository is free software: you can redistribute it and/or
modify it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

LetsMT! Resource Repository is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License along with
LetsMT! Resource Repository.  If not, see <http://www.gnu.org/licenses/>.
