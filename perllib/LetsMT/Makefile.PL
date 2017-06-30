use inc::Module::Install;

name          'LetsMT';
all_from      'lib/LetsMT.pm';

install_script 'bin/letsmt_admin';
install_script 'bin/letsmt_align';
install_script 'bin/letsmt_convert';
install_script 'bin/letsmt_fetch';
install_script 'bin/letsmt_import';
install_script 'bin/letsmt_rest';
install_script 'bin/letsmt_tokenize';
install_script 'bin/letsmt_detokenize';
install_script 'bin/letsmt_convert_columns';
install_script 'bin/letsmt_run';
install_script 'bin/letsmt_make';
install_script 'bin/letsmt_langdetect';
install_script 'bin/letsmt_chardetect';

install_share;


requires 'Cwd'     => 0;
requires 'Data::Dumper'     => 0;
requires 'Digest::MD5' => 0;
requires 'Encode'     => 0;
requires 'File::Basename'     => 0;
requires 'File::Copy::Recursive' => 0;
requires 'FileHandle'     => 0;
requires 'Filesys::DiskUsage' => 0;
requires 'File::Temp' => 0;
requires 'FindBin'     => 0;
requires 'HTTP::Request::Common' => 0;
requires 'Log::Log4perl' => 0;
requires 'LWP::UserAgent'     => 0;
requires 'Lingua::Sentence'     => 0;
requires 'Crypt::SSLeay' => 0;
requires 'TokyoCabinet'     => 0;
requires 'TokyoTyrant'     => 0;
requires 'URI::Escape'     => 0;
requires 'URI::Query'     => 0;
requires 'XML::Parser'     => 0;
requires 'XML::Simple'     => 0;
requires 'Switch'          =>0;
# requires       'XML::Writer'     => 0;


WriteAll;
