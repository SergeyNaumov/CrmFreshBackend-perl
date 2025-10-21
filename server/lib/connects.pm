package connects;

sub get{
  [
    {
      name=>'crm_read',
      user=>'yabikupil',
      host=>'localhost',
      dbname=>'yabikupil'
    },
    {
      name=>'crm_write',
      user=>'yabikupil',
      host=>'localhost',
      dbname=>'yabikupil'
    },

  ];
};
return 1;
