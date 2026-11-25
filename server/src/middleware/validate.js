import { AppError } from '../utils/AppError.js';

// validate({ body: zodSchema, query: zodSchema, params: zodSchema })
export const validate = (schemas) => (req, _res, next) => {
  for (const key of ['body', 'query', 'params']) {
    if (!schemas[key]) continue;
    const result = schemas[key].safeParse(req[key]);
    if (!result.success) {
      return next(new AppError('Validation failed', 400, result.error.flatten().fieldErrors));
    }
    req[key] = result.data;
  }
  next();
};
