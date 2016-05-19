#
# The Perl Pure RayCaster
# Perl Pure RayCaster is a simple Raycaster written completely in Perl, without use of any external libraries (like OpenGL etc.).
# This is for educational purposes, you can study methods commonly used and easily test new things.
# Do not expect advanced features found in ray tracers and speed of compiled languages.
#
# This file is part of the Perl Pure RayCaster
#
# Author:  Giannis Economou (geconomou@gmail.com)
# Created: 5/2004. Some additions, changes and the initial public release made on 1/2006
#
#
#DISCLAIMER
#This software is distributed in the hope that it will be useful, but is provided "AS IS" WITHOUT WARRANTY OF ANY KIND,
# either expressed or implied, INCLUDING, without limitation, the implied warranties of MERCHANTABILITY and FITNESS FOR A PARTICULAR PURPOSE.
#The ENTIRE RISK as to the quality and performance of the software IS WITH YOU (the holder of the software).
# Should the software prove defective, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.
#IN NO EVENT WILL ANY COPYRIGHT HOLDER OR ANY OTHER PARTY WHO MAY CREATE, MODIFY, OR DISTRIBUTE THE SOFTWARE BE LIABLE OR RESPONSIBLE TO YOU
# OR TO ANY OTHER ENTITY FOR ANY KIND OF DAMAGES (no matter how awful - not even if they arise from known or unknown flaws in the software).
#
#Please refer to 'Perl Pure RayCaster' site and to the Artistic License that came with your Perl distribution for more details.
#
#

# AffineTransform - class to represent Affine Transforms
#

package AffineTransform;
use strict;

use Vertex;

#class fields
#tMatrix:           object's transformation Matrix (final transform Matrix returned to caller)
#_identityMatrix:   (private) the identity Matrix
#_transStack:       a stack (Perl arrayref) to keep transformations, in order to compute final tMatrix
use fields qw (_identityMatrix tMatrix _transStack);

#object constructor
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my AffineTransform $self = fields::new($class);    #use pseudohash (array ref) for object blessing

    #the private identity Matrix
    $self->{_identityMatrix} = [
        qw(1 0 0 0
           0 1 0 0
           0 0 1 0
           0 0 0 1)
    ];

    #init tMatrix as an _identityMatrix
    $self->{tMatrix} = $self->{_identityMatrix};

    #init empty transformations stack
    $self->{_transStack} = ();

    return $self;
}

#returns the Identity Matrix
sub getIdentityMatrix() {
    my $self = shift;
    return @{ $self->{_identityMatrix} };
}

#Create a translation Matrix
# [ 1 0 0 dx ]
# [ 0 1 0 dy ]
# [ 0 0 1 dz ]
# [ 0 0 0  1 ]
#expects $dx, $dy, $dz
sub translate {
    my $self = shift;
    my ( $dx, $dy, $dz ) = @_;
    my @trMatrix = @{ $self->{_identityMatrix} };    #get the identity matrix

    $trMatrix[3]  = $dx;
    $trMatrix[7]  = $dy;
    $trMatrix[11] = $dz;

    #stack Matrix
    $self->_stackTransMatrix( \@trMatrix );

}

#perform a translation to an existing vertex
sub translate2Vertex {
    my $self = shift;
    my Vertex $destVertex = shift;
    $self->translate( $destVertex->{x}, $destVertex->{y}, $destVertex->{z} );
}

#Create a Matrix for X-axis rotation
# [ 1    0     0   0 ]
# [ 0  cos  -sin   0 ]
# [ 0  sin   cos   0 ]
# [ 0    0    0    1 ]
#expects $theta

sub rotateX {
    my $self      = shift;
    my $theta     = shift;
    my @rotMatrix = @{ $self->{_identityMatrix} };    #get the identity matrix

    $rotMatrix[9] = sin($theta);
    $rotMatrix[5] = $rotMatrix[10] = cos($theta);
    $rotMatrix[6] = -$rotMatrix[9];

    #stack Matrix
    $self->_stackTransMatrix( \@rotMatrix );
}

#Create a Matrix for Z-axis rotation
# [  cos  -sin   0   0 ]
# [  sin   cos   0   0 ]
# [    0     0   1   0 ]
# [    0     0   0   1 ]
#expects $theta
sub rotateZ {
    my $self      = shift;
    my $theta     = shift;
    my @rotMatrix = @{ $self->{_identityMatrix} };    #get the identity matrix

    $rotMatrix[4] = sin($theta);
    $rotMatrix[0] = $rotMatrix[5] = cos($theta);
    $rotMatrix[1] = -$rotMatrix[4];

    #stack Matrix
    $self->_stackTransMatrix( \@rotMatrix );

}

#Create a Matrix for Y-axis rotation
# [  cos    0    sin   0 ]
# [    0    1      0   0 ]
# [ -sin    0    cos   0 ]
# [    0    0      0   1 ]
#expects $theta
sub rotateY {
    my $self      = shift;
    my $theta     = shift;
    my @rotMatrix = @{ $self->{_identityMatrix} };    #get the identity matrix
    $rotMatrix[2] = sin($theta);
    $rotMatrix[0] = $rotMatrix[10] = cos($theta);
    $rotMatrix[8] = -$rotMatrix[2];

    #stack Matrix
    $self->_stackTransMatrix( \@rotMatrix );
}

#Create a Matrix for scaling
# [ s 0 0 0 ]
# [ 0 s 0 0 ]
# [ 0 0 s 0 ]
# [ 0 0 0 s ]
#expects a $scaleFactor (s)
sub scale {
    my $self        = shift;
    my $scaleFactor = shift;
    my @scaleMatrix = @{ $self->{_identityMatrix} };    #get the identity matrix

    $scaleMatrix[0] = $scaleMatrix[5] = $scaleMatrix[10] = $scaleFactor;

    #stack Matrix
    $self->_stackTransMatrix( \@scaleMatrix );
}

#Let the caller specify an arbitrary transform Matrix.
#Expects an array reference.
sub arbitraryMatrix {
    my $self    = shift;
    my $tMatrix = shift;

    my @arbMatrix = @$tMatrix;

    #stack Matrix
    $self->_stackTransMatrix( \@arbMatrix );
}

#Returns the Matrix to the caller as an array ref.
sub getFinalTransformMatrix() {
    my $self = shift;
    $self->concatenateTransforms();

    return $self->{tMatrix};
}

#push a transformation Matrix onto the transformations stack
#transformations are stacked and concatenated if reverse order when the
#final transformation matrix is requested
sub _stackTransMatrix {
    my $self        = shift;
    my $transMatrix = shift;
    push @{ $self->{_transStack} }, $transMatrix;
}

#Concatenates all transformation Matrices on the stack to form the final transformation Matrix.
#Multiplies all given transformation Matrices in reverse than given order
sub concatenateTransforms() {
    my $self = shift;

    my $resultMatrix = undef;
    my $oldMatrix    = @$self->{tMatrix};                        #final transformation Matrix so far
    while ( my $stackMatrix = pop @{ $self->{_transStack} } ) {  #get next Matrix from stack
        $oldMatrix    = @$self->{tMatrix};                       #final transformation Matrix so far
        $resultMatrix = [qw(	0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)];

        #multiply the two 4x4 Matrices: ($oldMatrix * $aMatrix)
        for ( my $i = 0, my $k = 0; $i < 16; $i++ ) {
            $k = ( int( $i / 4 ) ) * 4;
            for ( my $j = ( $i % 4 ); $j < 16; $j += 4 ) {
                $resultMatrix->[$i] += $oldMatrix->[$k++] * $stackMatrix->[$j];
            }
        }
        $self->{tMatrix} = $resultMatrix;

      #print "AffineTransform::concatenateTransforms - while stacking matrixes we've got intermediate result: @${resultMatrix}\n";
    }

    #print "AffineTransform::concatenateTransforms After all stacked matrices we've got result matrix: @${resultMatrix}\n";
}

1;
