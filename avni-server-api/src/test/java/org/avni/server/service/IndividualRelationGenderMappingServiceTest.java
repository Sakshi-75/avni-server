package org.avni.server.service;

import org.avni.server.dao.individualRelationship.IndividualRelationGenderMappingRepository;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class IndividualRelationGenderMappingServiceTest {
    @Mock private IndividualRelationGenderMappingRepository repository;
    private IndividualRelationGenderMappingService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new IndividualRelationGenderMappingService(repository);
    }
    
    @Test
    public void testIsNonScopeEntityChanged() {
        DateTime dateTime = DateTime.now();
        when(repository.existsByLastModifiedDateTimeGreaterThan(dateTime)).thenReturn(true);
        
        boolean result = service.isNonScopeEntityChanged(dateTime);
        
        assertTrue(result);
    }
}
