[


      sub{
        #use Plugin::Search::XLS;

        use Plugin::Search::works_xml;
        #use Plugin::Search::Journal;
        use Plugin::Search::JournalXLS;
        
        #Plugin::Search::XLS::go($form);
        Plugin::Search::works_xml::go($form);
        #Plugin::Search::Journal::go($form);
        Plugin::Search::JournalXLS::go($form);
        #pre(  );
        if($form->{manager}->{login} eq 'admin' || $form->{manager}->{permissions}->{operator}){
            $form->{make_delete}=1;
            $form->{read_only}=0;
            $form->{not_create}=0,
        }
        if($form->{script} eq 'edit_form'){
            $form->{title}='Регистрация работ по выездной поверке';
        }
        if($form->{id}){
          
          $form->{ov}=$form->{db}->query(
            query=>'select * from work where id=?',
            values=>[$form->{id}],
            onerow=>1
          );
          #print Dumper({ov=>$form->{ov}});
        }
      }
      
]