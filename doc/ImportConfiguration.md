# Configuration of automatic import and alignment #

There are several parameters that may influence the conversion and alignment of imported documents. We distinguish between two types of parameters: **import parameters** and **alignment parameters**. Import parameters are specified with the prefix 'ImportPara_' and alignment parameters use the prefix 'AlignPara_'.

## Configuration of import parameters ##

Import parameters can be set at several levels:

 * user-specific configuration (that will be used for all uploads by a specific user)
 * corpus-specific configuration (used for all uploads to this corpus, attached to `slot/user/uploads`)
 * document-type-specific configuration (used for all documents of a particular type within a specific corpus stored at `slot/user/uploads` with additional prefix 'type_', for example, 'ImportPara_pdf_' for import parameters that are used for PDF documents)
 * resource-specific configuration (used for importing a specific resource `/slot/user/path/to/resource`)

Configuration at a lower level overwrites settings of higher levels. This means that user-specific configuration overwrites default settings, corpus-specific configuration overwrites user-specific settings, document-type-specific configuration overwrites corpus-specific settings and resource-specific configuration overwrites document-type-specific settings. For example, the settings for '!ImportPara_splitter' for a specific resource overwrite the settings for the same parameter at the corpus level which overwrites possible settings of this parameter at the user level. The following parameters can be set in the current implementation:


### General parameters for import and conversion: ###

| **parameter** | **type** | **possible values** | **description** |
|---------------|----------|---------------------|-----------------|
| ImportPara_normalizer | string | whitespace/header/ligatures/dos/moses | comma-separated chain of text normalizers |
| ImportPara_splitter   | string | europarl/lingua/opennlp/udpipe   | text splitter (used for sentence boundary detection) |
| ImportPara_tokenizer  | string | europarl/uplug/whitespace | tokenizer (but: standard import does not tokenize) |
| ImportPara_autoalign  | string | on|off                    | automatically detect and align parallel documents (default=on) |
| ImportPara_trust_langid | string | on|off      | trust language detection (default=on) |


### Parameters for importing PDF documents ###

| **parameter** | **type** | **possible values** | **description** |
|---------------|----------|---------------------|-----------------|
| ImportPara_mode | string | layout/raw/standard/tika/pdf2xml | PDF conversion mode (default = pdf2xml) |


These parameters are stored in the group database (user-specific configuration) and in the metadata database (corpus-specific and resource-specific configuration). More information about setting and manipulating these settings can be found at the end of this page.



## Configuration of alignment parameters ##

Sentence alignment parameters can be set on three levels:

 * User-level (stored in group database)
 * corpus-level (stored at `/slot/user/uploads`)
 * resource-level (stored at `/slot/user/path/to/resource`)

There are parameters that influence the search for parallel documents and parameters influencing the algorithm used for automatic alignment. Here is a list of the currently supported parameters:


### Parameters influencing the search for parallel documents ###

| **parameter** | **type** | **possible values** | **description** |
|---------------|----------|---------------------|-----------------|
| AlignPara_search_parallel | string | identical|similar | specifies the method to match documents (identical names or similar names) |
| AlignPara_search_parallel_min_size_ratio | float | 0.0 - 1.0 | threshold for the document size ratio |
| AlignPara_search_parallel_min_name_match | float | 0.0 - 1.0 | threshold for the name match |
| AlignPara_search_parallel_weight_size_ratio | float | 0.0 - 1.0 | interpolation weight for combing size match with name match |
| AlignPara_search_parallel_weight_name_match | float | 0.0 - 1.0 | interpolation weight for combing size match with name match |

### Parameters influencing the automatic sentence alignment: ###

| **parameter** | **type** | **possible values** | **description** |
|---------------|----------|---------------------|-----------------|
| AlignPara_method | string | one-to-one/GaleChurch/hunalign/bisent | method to be used for automatic sentence alignment |

### Parameters for the Gale & Church alignment method: ###

| **parameter** | **type** | **description** |
|---------------|----------|-----------------|
| AlignPara_mean | float | mean length-diff distribution (default=1)  |
| AlignPara_variance     | float | variance of length-diff distribution (default=6.8)  |
| AlignPara_search_window | int | max distance from diagonal (default=50)  |
| AlignPara_pillow         | binary | 1 = create pillow-shaped search space (default=1)  |

### Parameters for hunalign: ###

| **parameter** | **type** | **description** |
|---------------|----------|-----------------|
| AlignPara_dic | string | path to bilingual dictionary (default: empty dic) |
| AlignPara_para | string | hunalign parameters (default for hunalign: '-realign'; default for bisent: '-realign -cautious') |


## Possible parameters for import and conversion: ##

| **parameter** | **type** | **description** |
|---------------|----------|-----------------|
| ImportPara_normalizer | string | comma-separated chain of text normalizers |
| ImportPara_splitter | string | text splitter (used for sentence boundary detection) |
| ImportPara_tokenizer | string | tokenizer (but: standard import does not tokenize) |

### Parameters for importing PDF documents ###

| **parameter** | **type** | **possible values** | **description** |
|---------------|----------|---------------------|-----------------|
| mode | string | layout/raw/standard | PDF conversion mode (default = layout) |



### User-specific configuration ###


User-specific configuration is stored in the group database in the group named by the user ID. Key-value pairs can be set/read/delete using the group API by adding attributes to API request accordingly. Key/value pairs can refer to any of the parameters listed above. You can add a prefix corresponding to the document type to restrict a parameter to this document type only. For example: ` ImportPara_pdf_mode=raw ` will set the import mode for pdf files to 'raw'. 



Show user configuration:
```
  $LETSMT_CONNECT -X GET "$LETSMT_URL/group/<user>?uid=<user>&action=showinfo"
  letsmt_rest -u <user> userinfo
```

Set user configuration (overwrites values of existing keys):
```
  $LETSMT_CONNECT -X POST "$LETSMT_URL/group/<user>?uid=<user>&<key1>=<value1>&<key2>=<value2>..."
  letsmt_rest -u <user> -m "<key1>=<value1>:<key2>=<value2>..." set_userinfo
```

Add user configuration (adding values to existing keys):
```
  $LETSMT_CONNECT -X PUT "$LETSMT_URL/group/<user>?uid=<user>&<key1>=<value1>&<key2>=<value2>..."
  letsmt_rest -u <user> -m "<key1>=<value1>:<key2>=<value2>..." add_userinfo
```

Delete keys/values from the user configuration:
```
  $LETSMT_CONNECT -X DELETE "$LETSMT_URL/group/<user>?uid=<user>&<key1>=<value1>&<key2>=<value2>..."
  letsmt_rest -u <user> -m "<key1>=<value1>:<key2>=<value2>..." del_userinfo
```


### Corpus/resource-specific configuration ###

Corpus-specific settings and resource-specific settings can be added as metadata using the usual calls to the metadata API. Corpus-specific settings are stored attached to 
```<slot>/<user>/uploads`, document-type-specific settings are attached to `<slot>/<user>/uploads/<type>` and resource-specific settings are attached to `<slot>/<user>/uploads/<path_to_resource>`.

For example:

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/metadata/slot/user/uploads/pdf?uid=user&ImportPara_mode=raw"
```

changes the conversion mode for PDF files to 'raw' for all coming uploads to slot <slot> in the user branch <user>. Note that document-type-specific configuration can only be used for import parameters (not alignment parameters). In any case, resource-specific settings can overwrite this general behavior: For example,

```
$LETSMT_CONNECT -X POST "$LETSMT_URL/metadata/slot/user/uploads/pdf/test.pdf?uid=user&ImportPara_mode=standard"
```

sets the conversion mode to 'standard' for the resource 'test.pdf'.
