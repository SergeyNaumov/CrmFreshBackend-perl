sub send_mes{
  my ($self,%args)=@_;
  $args{subject}=encode('MIME-Header', $args{subject});
    return unless($args{to});
    return unless($args{from});
    my $letter = MIME::Lite->new(
    From => $args{from},
        To => $args{to},
        #Return-Path => $args{from},
        Subject => $args{subject},
        Type=> 'multipart/mixed',
    ) || die "Can't create $!";

  if($args{template}){
    $args{message}=$self->template({template=>$args{template},vars=>$args{vars}});
  }
  # разбиваем на строки, чтобы не было кракозябр:
  $args{message}=~s/([^\n]{30,50})\s/$1\n/gs;

    #print $args{message};
    Encode::_utf8_off($args{message});

    # attach body
    $letter->attach (
    Type => 'text/html; charset=UTF-8',
    Data => $args{message}
  ) or warn "Error adding the text message part: $!\n";

  foreach my $f (@{$args{files}}){
      $letter->attach(
        Type => 'AUTO',
        Disposition => 'attachment',
        Filename => $f->{filename},
        Path => $f->{full_path},
      );
  }

  $letter->send();

}



return 1;
