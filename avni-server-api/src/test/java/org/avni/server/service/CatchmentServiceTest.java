package org.avni.server.service;

import jakarta.persistence.EntityManager;
import org.avni.server.dao.CatchmentRepository;
import org.avni.server.dao.LocationRepository;
import org.avni.server.domain.AddressLevel;
import org.avni.server.domain.Catchment;
import org.avni.server.domain.Organisation;
import org.avni.server.domain.UserContext;
import org.avni.server.framework.security.UserContextHolder;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

public class CatchmentServiceTest {
    @Mock private EntityManager entityManager;
    @Mock private CatchmentRepository catchmentRepository;
    @Mock private LocationRepository locationRepository;
    
    private CatchmentService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new CatchmentService(entityManager, catchmentRepository, locationRepository);
        
        Organisation org = new Organisation();
        UserContext context = new UserContext();
        context.setOrganisation(org);
        UserContextHolder.create(context);
    }
    
    @Test
    public void testCreateOrUpdateNewCatchment() {
        AddressLevel location = new AddressLevel();
        location.setUuid("loc-uuid");
        
        when(catchmentRepository.findByNameIgnoreCase("Test Catchment")).thenReturn(null);
        when(catchmentRepository.save(any(Catchment.class))).thenReturn(new Catchment());
        
        Catchment result = service.createOrUpdate("Test Catchment", location);
        
        assertNotNull(result);
        verify(catchmentRepository).save(any(Catchment.class));
    }
    
    @Test
    public void testCreateOrUpdateExistingCatchment() {
        AddressLevel location = new AddressLevel();
        location.setUuid("loc-uuid");
        
        Catchment existing = new Catchment();
        existing.setName("Test Catchment");
        when(catchmentRepository.findByNameIgnoreCase("Test Catchment")).thenReturn(existing);
        when(catchmentRepository.save(any(Catchment.class))).thenReturn(existing);
        
        Catchment result = service.createOrUpdate("Test Catchment", location);
        
        assertNotNull(result);
        verify(catchmentRepository).save(any(Catchment.class));
    }
}
