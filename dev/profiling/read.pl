use Devel::NYTProf::Data;
 
$profile = Devel::NYTProf::Data->new( { filename => 'nytprof.out' } );
 
$profile->dump_profile_data();
