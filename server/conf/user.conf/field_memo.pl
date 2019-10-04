# Комментарий 
description=>'Комментарий',
name=>'memo',
type=>'memo',
method=>'multitable',
memo_table=>'user_memo',
memo_table_id=>'id',
memo_table_comment=>'body',
memo_table_auth_id=>'manager_id',
memo_table_registered=>'registered',
memo_table_foreign_key=>'user_id',
auth_table=>'manager',
auth_login_field=>'login',
auth_id_field=>'id',
auth_name_field=>'name',
reverse=>1,
format=>q{<b>[date]</b>  [edit_button] [delete_button] <span class="datetime">[hour]:[min]:[sec]  </span> [remote_name] <span class="message">[message]</span></div>},
memo_table_alias=>'memo',
auth_table_alias=>'m_memo',
where=>'type=1',
make_delete=>1,
make_edit=>1,
after_add=>sub{
  my $e=shift;
  my $sth=$form->{dbh}->prepare("UPDATE user_memo SET type=1 WHERE id = ?");
  $sth->execute($e->{id});
},

