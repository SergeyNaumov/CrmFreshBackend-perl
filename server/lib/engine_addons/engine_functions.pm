use MIME::Lite;
use MIME::Base64;
use File::Copy;
use utf8;
use Data::Dumper;
use Template;
sub print{
  my $self=shift;
  $self->print_header();
  my $data=shift;
  $self->{APP}->{DATA}.=$data;
  return $self;
}

sub pre{
  my $s=shift; my $d=shift; my $not_view=shift;
  unless($not_view){
    $s->print('<pre>'.Dumper($d)."</pre>\n")
  }
  else{
    $s->print('<pre style="display: none;">'.Dumper($d)."</pre>\n")
  }
};

sub print_error{
  my $self=shift;
  my $data=shift;
  $self->{APP}->{STATUS}=500 unless($self->{APP}->{STATUS});
  $self->{APP}->{HEADERS}=['Content-type','text/html; charset=utf-8'];
  $self->{APP}->{DATA}='' unless($self->{APP}->{DATA});
  $self->{APP}->{DATA}.=$data;
  $self->end();
  return $self;
}


sub from_tmpl{
  my $s=shift;
  my $var=shift;
  my @subvars;
  if($var=~m/^([^.:]+)[\.:](.+)$/){
    $var=$1;
    @subvars=split /[\.:]/, $2;
    #print Dumper(\@subvars);
  }

  my $d=$s->{vars}->{TMPL_VARS}->{$var};
  foreach my $sw (@subvars){
    $d=$d->{$sw};
  }
  return $d;
}
sub to_tmpl{
  my $self=shift;
  my $p=shift;
  my $value=shift;
  #my $p='LIST:art';
  my $eval_str='$self->{vars}->{TMPL_VARS}';
  foreach my $key ((split /[:]/,$p)){
    $eval_str.=qq{->{$key}}
  }
  $eval_str.='=$value';
  eval $eval_str;
  #print "$eval_str\n";
  #pre($self->{vars}->{TMPL_VARS});
  return $self;
}
sub print_template{
  my $self=shift;
  my $opt=shift;
  $self->print_header();
  $self->{APP}->{DATA}='' unless($self->{APP}->{DATA});
  $self->{APP}->{DATA}.=$self->template($opt);
  return $self;
}

sub template{
  my $self=shift;
  #my $template_name=shift;

  my $opt=shift;

  #print Dumper($self);
  #unless(ref($opt)){
  #  $opt={template=>$opt}
  #}
  #elsif($opt->{dir}){

    #$opt->{dir}='./views/';
    #$self->{vars}->{TEMPLATE_FOLDER}.$opt->{dir};
  #}
  unless($opt->{dir}){
    #print "opt: ".Dumper($opt);
    if($opt->{template}=~m/^(.+)\/([^\/]+)$/){
      $opt->{template}=~s/^\.?\///;
      $opt->{dir}='./views/'.$1;
      $opt->{template}=$2;
    }
    else{
      #print "2\n";
      #print Dumper($self->{vars}->{TEMPLATE_FOLDER});
      $self->{vars}->{TEMPLATE_FOLDER}=$self->{vars}->{TEMPLATE_FOLDER} unless($self->{vars}->{TEMPLATE_FOLDER});
      $opt->{dir}='./views';
    }

  }
  #print Dumper($self->{vars});
  $opt->{vars}=$self->{vars}->{TMPL_VARS} unless($opt->{vars});

  #die(q{not value in $self->{controller}->{layout}}) if(!defined($self->{controller}->{layout}));
  #my $filters=undef;
  #$filters=$self->{template_filters} if($self->{template_filters});

  my $template = Template->new(
  {
      INCLUDE_PATH => $opt->{dir},
      #COMPILE_EXT => '.tt2',
      #COMPILE_DIR=>'./tmp/ttc',
      CACHE_SIZE => 512,
      PRE_CHOMP  => 1,
      POST_CHOMP => 1,
      DEBUG_ALL=>1,
      ENCODING => 'utf8',
      #EVAL_PERL=>1,
      RELATIVE=>1,
      FILTERS=>#$self->{template_filters}
      #{
        #get_url=>sub{return $_[0];},
        #safe_xss=>\&safe_xss
      #}

  });
  my $output;
  #print "t: $opt->{template}";
  $template -> process($opt->{template}, $opt->{vars},\$output);
  if($template->error()){
    print "output::add_template: template error: ".$template->error()."\n";
    die "output::add_template: template error: ".$template->error();

  };

  $self->{vars}->{end}=1 if($opt->{end});
  #$self->print('<pre>'.Dumper($self->{vars}).'</pre>');
  return $output;
}
sub gen_pas{
    my $s=shift;
		my $len=shift;
		my $symbols=shift;
		$len=20 unless($len);
		$symbols='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' unless($symbols);
		my $key='';
		foreach my $k (1..$len){
			$key.=substr($symbols,int(rand(length($symbols))),1)
		}
		return $key
}
return 1;
