use Ufal::UDPipe;
use open qw(:std :utf8);
 
my $model_file = 'english-ud-2.0-170801.udpipe';
my $model = Ufal::UDPipe::Model::load($model_file);
$model or die "Cannot load model from file '$model_file'\n";
 
my $tokenizer = $model->newTokenizer($Ufal::UDPipe::Model::DEFAULT);
my $conllu_output = Ufal::UDPipe::OutputFormat::newOutputFormat("conllu");
my $sentence = Ufal::UDPipe::Sentence->new();
 
$tokenizer->setText(join('', <>));
while ($tokenizer->nextSentence($sentence)) {
    $model->tag($sentence, $Ufal::UDPipe::Model::DEFAULT);
    $model->parse($sentence, $Ufal::UDPipe::Model::DEFAULT);
 
    my $output = $conllu_output->writeSentence($sentence);
    print $output;
}
