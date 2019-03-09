

# use TokyoCabinet;
# TokyoCabinet::TDB->new();



 use LetsMT::Repository::DB::TokyoCabinet;
 
 # open the default database (LETSMTDISKROOT/metadata.tct)
 my $metaDB = new LetsMT::Repository::DB::TokyoCabinet();



#use LetsMT::Repository::DB::TokyoTyrant;
#my $metaDB = new LetsMT::Repository::DB::TokyoTyrant(
#     -host => 'localhost', -port => 1980);

$metaDB->open_read('/var/lib/letsmt/metadata.tct');
my $result = $metaDB->get_xml(\$message,'corpus/user/xml/en-es/207.xml');
my $search = $metaDB->search_xml(1,\$message, { 'resource-type' => sentalign, 
						'STARTS_WITH__ID_' =>  'corpus2/user/xml/fi-sv'} );


print '';
