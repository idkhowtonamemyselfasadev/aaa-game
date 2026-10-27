shader_type spatial;
// Brown hare fur shells: the body mesh pushed out along its posed normal by shell_h x
// fur_len and cut to sparse hair tips, so the coat breaks the silhouette into fuzz and
// reads as fur instead of a smooth painted skin. hare.gd chains three as next_pass.
#define SHELL
#include "res://shaders/hare_body.gdshaderinc"
