constant doc = "Generic matrix filter. Specify a 'matrix' argument with a matrix, row and space separated like this:<pre>matrix='x x x x x x\nx x x x x x\nx x x x x x'</pre>The matrix can be any size. All rows must be of the same size. You can specify a base color using the 'color' argument, and a divisor using the 'divisor' argument.";

void render( mapping args, mapping this, string channel, object id, object m )
{
  array color = Colors.parse_color( args->color||"black" );
  if(!this[channel]) return;
  array matrix = (args->matrix||"0 1 0\n1 2 1\n0 1 0")/"\n";
  matrix = Array.map(matrix, lambda(string s){
			       return (array(int))(s/" "-({""}));
			     });
  
  if(args->divisor = (int)args->divisor)
    this[channel]=this[channel]->apply_matrix(matrix,@color,args->divisor);
  else
    this[channel]=this[channel]->apply_matrix(matrix,@color);
}
