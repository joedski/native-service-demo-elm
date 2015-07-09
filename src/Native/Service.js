// Largely modeled after elm-http's native.
// Subject to breakages without notice due to compiler changes, etc, etc.

// Use F2, F3, etc if the function returned takes multiple arguments.
// Not necessary for functions of one argument.

Elm.Native.Service = Elm.Native.Service || {};
Elm.Native.Service.make = function( localRuntime ) {
	localRuntime.Native = localRuntime.Native || {};
	localRuntime.Native.Service = localRuntime.Native.Service || {};

	if( localRuntime.Native.Service.values ) {
		return localRuntime.Native.Service.values;
	}

	// Imports.
	
	var Task = Elm.Native.Task.make( localRuntime );

	function send( request ) {
		console.log( "Creating a send for request:", request );

		return Task.asyncFunction( function( callback ) {
			// Task.succeed( callback( responseValue ) );
			// Task.fail( callback( errorValue ) );

			var requestType = request.ctor;
			var responseFn;

			// We know that Elm will enforce a Float coming with the Request
			// if we have a Request that may result in calling this,
			// so we don't need to check the request.
			function succeedWithNumber() {
				callback( Task.succeed( getRandomNumberResponse( request._0 ) ) );
			}

			function failWithError() {
				callback( Task.fail( pickRandomError() ) );
			}

			switch( requestType ) {
				case 'GetRandomNumber':
					responseFn = succeedWithNumber;
					break;

				case 'GetAnError':
					responseFn = failWithError;
					break;

				default:
				case 'GetNumberOrError':
					var chance = Math.random() * 2 >> 0;

					if( chance === 0 ) {
						responseFn = succeedWithNumber;
					}
					else {
						responseFn = failWithError;
					}
					break;
			}

			// Wait for 3 seconds then call the result fn.
			setTimeout( responseFn, 3000 );
		});
	}

	function getRandomNumberResponse( max ) {
		return {
			ctor: 'RandomNumber',
			_0: Math.random() * max
		}
	}

	function pickRandomError() {
		// Note the property names.  This is part of what makes this fragile.
		var errorCount = errorMakers.length;
		var index = Math.random() * errorCount >> 0;
		return errorMakers[ index ]();
	}

	var errorMakers = [
		function() {
			return {
				ctor: 'ErrorWithMessage',
				_0: "Oh no!  Some possibly very specific error occurred!"
			};
		},
		function() {
			return {
				ctor: 'GenericError'
			};
		}
	]

    return localRuntime.Native.Service.values = {
    	send: send
    };
}
